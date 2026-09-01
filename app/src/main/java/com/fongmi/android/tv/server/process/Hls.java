package com.fongmi.android.tv.server.process;

import com.fongmi.android.tv.Setting;
import com.fongmi.android.tv.server.Nano;
import com.fongmi.android.tv.server.Server;
import com.fongmi.android.tv.server.impl.Process;
import com.github.catvod.net.XgHttp;
import com.github.catvod.net.XgResponse;
import com.orhanobut.logger.Logger;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.Function;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import fi.iki.elonen.NanoHTTPD;
public class Hls implements Process {

    private static final String TAG = Hls.class.getSimpleName();
    private static final String PATH = "/adm3u8/";
    private static final String MIME = "application/vnd.apple.mpegurl";
    private static final int MAX_PLAYLIST_SIZE = 1024 * 1024;
    private static final int MAX_SOURCES = 128;
    private static final Pattern URI_ATTR = Pattern.compile("URI=\"([^\"]+)\"");
    private static final AtomicLong IDS = new AtomicLong();
    private static final Map<String, Source> SOURCES = new LinkedHashMap<>();

    public static String getUrl(String url, Map<String, String> headers, String format) {
        if (!Setting.isVideoPurify() || !isHls(url, format)) return url;
        Server.get().start();
        return register(url, headers);
    }

    private static boolean isHls(String url, String format) {
        if (url == null) return false;
        String value = url.toLowerCase(Locale.ROOT);
        String type = format == null ? "" : format.toLowerCase(Locale.ROOT);
        if (!value.startsWith("http://") && !value.startsWith("https://")) return false;
        return value.matches("^https?://.*\\.m3u8(?:[?#].*)?$") || type.contains("m3u8") || type.contains("mpegurl") || type.contains("hls");
    }

    private static String register(String url, Map<String, String> headers) {
        String id = Long.toHexString(IDS.incrementAndGet());
        synchronized (SOURCES) {
            SOURCES.put(id, new Source(url, new HashMap<>(headers)));
            while (SOURCES.size() > MAX_SOURCES) SOURCES.remove(SOURCES.keySet().iterator().next());
        }
        return Server.get().getAddress(PATH + id + ".m3u8");
    }

    private static Source getSource(String url) {
        String id = url.substring(PATH.length());
        if (id.endsWith(".m3u8")) id = id.substring(0, id.length() - 5);
        synchronized (SOURCES) {
            return SOURCES.get(id);
        }
    }

    @Override
    public boolean isRequest(NanoHTTPD.IHTTPSession session, String url) {
        return url.startsWith(PATH);
    }

    @Override
    public NanoHTTPD.Response doResponse(NanoHTTPD.IHTTPSession session, String url, Map<String, String> files) {
        Source source = getSource(url);
        if (source == null) return Nano.error(NanoHTTPD.Response.Status.NOT_FOUND, "Playlist expired");
        try (XgResponse response = XgHttp.call(source.url, source.headers).execute()) {
            if (!response.isSuccessful() || response.body() == null) return redirect(source.url);
            String baseUrl = response.url().toString();
            String content = read(response.body().byteStream());
            if (!content.startsWith("#EXTM3U")) return redirect(source.url);
            String result = rewrite(content, baseUrl, child -> register(child, source.headers));
            byte[] data = result.getBytes(StandardCharsets.UTF_8);
            NanoHTTPD.Response output = NanoHTTPD.newFixedLengthResponse(NanoHTTPD.Response.Status.OK, MIME, new ByteArrayInputStream(data), data.length);
            output.addHeader("Cache-Control", "no-store");
            return output;
        } catch (Throwable e) {
            Logger.t(TAG).e(e, "HLS filtering failed: %s", source.url);
            return redirect(source.url);
        }
    }

    private static String read(InputStream input) throws Exception {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        byte[] buffer = new byte[8192];
        int count;
        while ((count = input.read(buffer)) != -1) {
            if (output.size() + count > MAX_PLAYLIST_SIZE) throw new IllegalStateException("Playlist exceeds 1 MiB");
            output.write(buffer, 0, count);
        }
        String text = output.toString(StandardCharsets.UTF_8.name());
        return text.startsWith("\uFEFF") ? text.substring(1) : text;
    }

    private static NanoHTTPD.Response redirect(String url) {
        NanoHTTPD.Response response = NanoHTTPD.newFixedLengthResponse(NanoHTTPD.Response.Status.REDIRECT, NanoHTTPD.MIME_PLAINTEXT, "");
        response.addHeader("Location", url);
        response.addHeader("Cache-Control", "no-store");
        return response;
    }

    static String rewrite(String content, String baseUrl, Function<String, String> playlistProxy) {
        boolean trailingNewline = content.endsWith("\n");
        String[] values = content.replace("\r\n", "\n").replace('\r', '\n').split("\n", -1);
        List<String> lines = new ArrayList<>(List.of(values));
        boolean media = lines.stream().anyMatch(line -> line.startsWith("#EXTINF:"));
        rewriteReferences(lines, baseUrl, playlistProxy, media);
        return filter(join(lines, trailingNewline), baseUrl);
    }

    public static String filter(String content, String baseUrl) {
        boolean trailingNewline = content.endsWith("\n");
        String[] values = content.replace("\r\n", "\n").replace('\r', '\n').split("\n", -1);
        List<String> lines = new ArrayList<>(List.of(values));
        if (lines.stream().noneMatch(line -> line.startsWith("#EXTINF:"))) return content;
        List<Segment> segments = parseSegments(lines, baseUrl);
        Set<Integer> ads = findAds(segments);
        if (ads.isEmpty()) return content;
        List<String> result = removeAds(lines, segments, ads);
        Logger.t(TAG).d("Filtered %s of %s HLS segments", ads.size(), segments.size());
        return join(result, trailingNewline);
    }

    private static void rewriteReferences(List<String> lines, String baseUrl, Function<String, String> playlistProxy, boolean media) {
        for (int i = 0; i < lines.size(); i++) {
            String line = lines.get(i);
            if (line.startsWith("#") && line.contains("URI=\"")) {
                Matcher matcher = URI_ATTR.matcher(line);
                StringBuffer output = new StringBuffer();
                while (matcher.find()) {
                    String absolute = resolve(baseUrl, matcher.group(1));
                    boolean childPlaylist = isPlaylist(absolute) || !media && (line.startsWith("#EXT-X-MEDIA:") || line.startsWith("#EXT-X-I-FRAME-STREAM-INF:"));
                    String target = childPlaylist ? playlistProxy.apply(absolute) : absolute;
                    matcher.appendReplacement(output, "URI=\"" + Matcher.quoteReplacement(target) + "\"");
                }
                matcher.appendTail(output);
                lines.set(i, output.toString());
            } else if (!line.isEmpty() && !line.startsWith("#")) {
                String absolute = resolve(baseUrl, line);
                lines.set(i, media ? absolute : playlistProxy.apply(absolute));
            }
        }
    }

    private static boolean isPlaylist(String url) {
        return url.toLowerCase(Locale.ROOT).matches(".*\\.m3u8(?:[?#].*)?$");
    }

    private static String resolve(String baseUrl, String value) {
        try {
            return URI.create(baseUrl).resolve(value).toString();
        } catch (Exception e) {
            return value;
        }
    }

    private static List<Segment> parseSegments(List<String> lines, String baseUrl) {
        List<Segment> result = new ArrayList<>();
        int extInf = -1;
        int previousUri = -1;
        double duration = 0;
        for (int i = 0; i < lines.size(); i++) {
            String line = lines.get(i);
            if (line.startsWith("#EXTINF:")) {
                extInf = i;
                duration = parseDuration(line);
            } else if (extInf >= 0 && !line.isEmpty() && !line.startsWith("#")) {
                int start = previousUri < 0 ? firstBlockStart(lines, extInf) : previousUri + 1;
                result.add(new Segment(start, i, duration, resolve(baseUrl, line)));
                previousUri = i;
                extInf = -1;
            }
        }
        return result;
    }

    private static int firstBlockStart(List<String> lines, int extInf) {
        int start = extInf;
        for (int i = extInf - 1; i >= 0; i--) {
            String line = lines.get(i);
            if (line.startsWith("#EXT-X-KEY") || line.startsWith("#EXT-X-MAP") || line.startsWith("#EXT-X-DISCONTINUITY") || line.startsWith("#EXT-X-BYTERANGE") || line.startsWith("#EXT-X-PROGRAM-DATE-TIME")) start = i;
            else break;
        }
        return start;
    }

    private static double parseDuration(String line) {
        try {
            int end = line.indexOf(',');
            return Double.parseDouble(line.substring(8, end < 0 ? line.length() : end));
        } catch (Exception e) {
            return 0;
        }
    }

    private static Set<Integer> findAds(List<Segment> segments) {
        if (segments.size() < 6) return Set.of();
        Candidate best = null;
        List<Function<Segment, String>> keys = List.of(Hls::directoryKey, Hls::hostKey, Hls::filePrefixKey);
        for (Function<Segment, String> key : keys) {
            Candidate candidate = dominant(segments, key);
            if (candidate != null && (best == null || candidate.ratio > best.ratio)) best = candidate;
        }
        if (best == null) return Set.of();
        double total = segments.stream().mapToDouble(item -> item.duration).sum();
        double suspect = best.indexes.stream().mapToDouble(index -> segments.get(index).duration).sum();
        return total > 0 && suspect <= total * 0.5 ? best.indexes : Set.of();
    }

    private static Candidate dominant(List<Segment> segments, Function<Segment, String> keyFunction) {
        Map<String, Integer> counts = new HashMap<>();
        for (Segment segment : segments) {
            String key = keyFunction.apply(segment);
            if (!key.isEmpty()) counts.put(key, counts.getOrDefault(key, 0) + 1);
        }
        Map.Entry<String, Integer> dominant = counts.entrySet().stream().max(Map.Entry.comparingByValue()).orElse(null);
        if (dominant == null || dominant.getValue() == segments.size()) return null;
        double ratio = dominant.getValue() / (double) segments.size();
        if (ratio < 0.85) return null;
        Set<Integer> indexes = new HashSet<>();
        for (int i = 0; i < segments.size(); i++) if (!dominant.getKey().equals(keyFunction.apply(segments.get(i)))) indexes.add(i);
        return indexes.isEmpty() ? null : new Candidate(ratio, indexes);
    }

    private static String hostKey(Segment segment) {
        try {
            URI uri = URI.create(segment.url);
            return (uri.getScheme() + "://" + uri.getAuthority()).toLowerCase(Locale.ROOT);
        } catch (Exception e) {
            return "";
        }
    }

    private static String directoryKey(Segment segment) {
        try {
            URI uri = URI.create(segment.url);
            String path = uri.getPath();
            int end = path.lastIndexOf('/');
            return end < 0 ? hostKey(segment) : hostKey(segment) + path.substring(0, end + 1).toLowerCase(Locale.ROOT);
        } catch (Exception e) {
            return "";
        }
    }

    private static String filePrefixKey(Segment segment) {
        try {
            String path = URI.create(segment.url).getPath();
            String file = path.substring(path.lastIndexOf('/') + 1).toLowerCase(Locale.ROOT);
            int dot = file.lastIndexOf('.');
            if (dot > 0) file = file.substring(0, dot);
            String prefix = file.replaceFirst("[-_]?\\d+$", "");
            return prefix.isEmpty() ? file : prefix;
        } catch (Exception e) {
            return "";
        }
    }

    private static List<String> removeAds(List<String> lines, List<Segment> segments, Set<Integer> ads) {
        List<String> result = new ArrayList<>();
        Segment first = segments.get(0);
        result.addAll(lines.subList(0, first.start));
        boolean skipped = false;
        for (int i = 0; i < segments.size(); i++) {
            Segment segment = segments.get(i);
            if (ads.contains(i)) {
                skipped = true;
                continue;
            }
            List<String> block = lines.subList(segment.start, segment.uri + 1);
            if (skipped && block.stream().noneMatch(line -> line.startsWith("#EXT-X-DISCONTINUITY"))) result.add("#EXT-X-DISCONTINUITY");
            result.addAll(block);
            skipped = false;
        }
        result.addAll(lines.subList(segments.get(segments.size() - 1).uri + 1, lines.size()));
        return result;
    }

    private static String join(List<String> lines, boolean trailingNewline) {
        String result = String.join("\n", lines);
        if (!trailingNewline && result.endsWith("\n")) result = result.substring(0, result.length() - 1);
        return result;
    }

    private record Source(String url, Map<String, String> headers) {
    }

    private record Segment(int start, int uri, double duration, String url) {
    }

    private record Candidate(double ratio, Set<Integer> indexes) {
    }
}
