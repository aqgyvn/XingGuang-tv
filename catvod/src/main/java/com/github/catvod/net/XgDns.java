package com.github.catvod.net;

import androidx.annotation.NonNull;

import com.github.catvod.bean.Doh;
import com.github.catvod.utils.Util;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InterruptedIOException;
import java.net.HttpURLConnection;
import java.net.IDN;
import java.net.InetAddress;
import java.net.URL;
import java.net.UnknownHostException;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorCompletionService;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

public class XgDns {

    private static final int MAX_ALIASES = 12;
    private static final long LOOKUP_TIMEOUT_MS = 3000;
    private static final Map<String, List<String>> BOOTSTRAP = Map.of(
            "xn--v4q818bf34b.cc", List.of("38.97.254.231"),
            "xn--ihqu10cn4c.xn--v4q818bf34b.cc", List.of("38.97.254.231"),
            "xn--v4q818bf34b.top", List.of("38.97.254.231"),
            "xn--ihqu10cn4c.xn--v4q818bf34b.top", List.of("38.97.254.231")
    );
    private static final ExecutorService DNS_POOL = Executors.newCachedThreadPool(task -> {
        Thread thread = new Thread(task, "xg-dns");
        thread.setDaemon(true);
        return thread;
    });
    private final ConcurrentHashMap<String, String> map = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, List<InetAddress>> resolved = new ConcurrentHashMap<>();
    private volatile Doh doh;
    private volatile List<String> fallbacks = List.of();

    public void setDoh(Doh item) {
        doh = item == null || item.getUrl().isEmpty() ? null : item;
    }

    public void setFallbacks(List<Doh> items) {
        if (items == null) {
            fallbacks = List.of();
            return;
        }
        fallbacks = items.stream()
                .filter(Objects::nonNull)
                .map(Doh::getUrl)
                .filter(url -> !url.isEmpty())
                .distinct()
                .toList();
    }

    void setFallbackUrls(List<String> urls) {
        fallbacks = urls == null ? List.of() : urls.stream()
                .filter(Objects::nonNull)
                .map(String::trim)
                .filter(url -> !url.isEmpty())
                .distinct()
                .toList();
    }

    public void clear() {
        map.clear();
        resolved.clear();
        doh = null;
    }

    public void addAll(List<String> hosts) {
        map.putAll(hosts.stream().filter(Objects::nonNull).map(host -> host.split("=", 2)).filter(splits -> splits.length == 2).collect(Collectors.toMap(s -> s[0].trim(), s -> s[1].trim(), (oldHost, newHost) -> newHost)));
    }

    @NonNull
    public List<InetAddress> lookup(@NonNull String hostname) throws IOException {
        String target = get(hostname);
        if (!target.equals(hostname)) return List.of(InetAddress.getByName(target));
        Doh selected = doh;
        LinkedHashMap<String, InetAddress> addresses = new LinkedHashMap<>();
        IOException failure = null;
        ExecutorCompletionService<List<InetAddress>> completion = new ExecutorCompletionService<>(DNS_POOL);
        List<Future<List<InetAddress>>> tasks = new ArrayList<>();
        if (selected != null) {
            tasks.add(completion.submit(() -> lookupDoh(selected.getUrl(), hostname)));
        }
        tasks.add(completion.submit(() -> lookupSystem(hostname)));
        for (String fallback : fallbacks) {
            if (selected != null && selected.getUrl().equals(fallback)) continue;
            tasks.add(completion.submit(() -> lookupDoh(fallback, hostname)));
        }
        long deadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(LOOKUP_TIMEOUT_MS);
        for (int i = 0; i < tasks.size(); i++) {
            long remaining = deadline - System.nanoTime();
            if (remaining <= 0) break;
            try {
                Future<List<InetAddress>> task = completion.poll(remaining, TimeUnit.NANOSECONDS);
                if (task == null) break;
                addAll(addresses, task.get());
            } catch (InterruptedException error) {
                Thread.currentThread().interrupt();
                throw new InterruptedIOException("Canceled");
            } catch (ExecutionException error) {
                Throwable cause = error.getCause();
                if (cause instanceof IOException io) failure = io;
            }
        }
        for (Future<List<InetAddress>> task : tasks) if (!task.isDone()) task.cancel(true);
        if (!addresses.isEmpty()) {
            List<InetAddress> values = new ArrayList<>(addresses.values());
            values.sort((left, right) -> Integer.compare(addressRank(left), addressRank(right)));
            values = List.copyOf(values);
            resolved.put(hostname, values);
            return values;
        }
        List<InetAddress> cached = resolved.get(hostname);
        if (cached != null && !cached.isEmpty()) return cached;
        List<InetAddress> bootstrap = lookupBootstrap(hostname);
        if (!bootstrap.isEmpty()) {
            resolved.put(hostname, bootstrap);
            return bootstrap;
        }
        UnknownHostException error = new UnknownHostException(hostname);
        if (failure != null) error.initCause(failure);
        throw error;
    }

    private List<InetAddress> lookupBootstrap(String hostname) throws IOException {
        List<String> values = BOOTSTRAP.get(toAscii(hostname));
        if (values == null || values.isEmpty()) return List.of();
        List<InetAddress> addresses = new ArrayList<>();
        for (String value : values) addresses.add(InetAddress.getByName(value));
        return List.copyOf(addresses);
    }

    private void addAll(LinkedHashMap<String, InetAddress> addresses, List<InetAddress> values) {
        for (InetAddress value : values) addresses.putIfAbsent(value.getHostAddress(), value);
    }

    private int addressRank(InetAddress value) {
        return value.getAddress().length == 4 ? 0 : 1;
    }

    List<InetAddress> lookupSystem(String hostname) throws IOException {
        return List.of(InetAddress.getAllByName(toAscii(hostname)));
    }

    private String get(String hostname) {
        String target = map.get(hostname);
        if (target != null) return target;
        for (Map.Entry<String, String> entry : map.entrySet()) if (Util.containOrMatch(hostname, entry.getKey())) return entry.getValue();
        return hostname;
    }

    String mappedHost(String hostname) {
        return get(hostname);
    }

    boolean hasDoh() {
        return doh != null;
    }

    List<InetAddress> lookupDoh(String endpoint, String hostname) throws IOException {
        List<String> pending = new ArrayList<>();
        pending.add(hostname);
        Set<String> visited = new LinkedHashSet<>();
        LinkedHashMap<String, InetAddress> addresses = new LinkedHashMap<>();
        while (!pending.isEmpty() && visited.size() < MAX_ALIASES) {
            String current = toAscii(pending.remove(0));
            if (!visited.add(current)) continue;
            DnsResult ipv4 = queryDoh(endpoint, current, 1);
            DnsResult ipv6 = queryDoh(endpoint, current, 28);
            addAll(addresses, ipv4.addresses());
            addAll(addresses, ipv6.addresses());
            Set<String> aliases = new LinkedHashSet<>();
            aliases.addAll(ipv4.aliases());
            aliases.addAll(ipv6.aliases());
            for (String alias : aliases) {
                String value = toAscii(alias);
                if (!value.isEmpty() && !visited.contains(value)) pending.add(value);
            }
        }
        return List.copyOf(addresses.values());
    }

    private DnsResult queryDoh(String endpoint, String hostname, int type) throws IOException {
        byte[] query = dnsQuery(hostname, type);
        String separator = endpoint.contains("?") ? "&" : "?";
        String encoded = java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(query);
        URL url = new URL(endpoint + separator + "dns=" + encoded);
        HttpURLConnection connection = (HttpURLConnection) url.openConnection();
        connection.setConnectTimeout(10000);
        connection.setReadTimeout(10000);
        connection.setRequestProperty("Accept", "application/dns-json, application/dns-message");
        connection.setRequestProperty("User-Agent", Util.XGHTTP);
        try {
            int status = connection.getResponseCode();
            if (status / 100 != 2) throw new IOException("DoH HTTP " + status + " (" + url.getHost() + ")");
            byte[] response = readBytes(connection.getInputStream());
            String contentType = connection.getHeaderField("Content-Type");
            String mime = contentType == null ? "" : contentType.toLowerCase(Locale.ROOT);
            if (mime.contains("dns-message")) return parseDns(response);
            if (mime.contains("json")) return parseJson(response);
            int first = firstNonWhitespace(response);
            if (first >= 0 && response[first] == '{') {
                try {
                    return parseJson(response);
                } catch (IOException ignored) {
                    return parseDns(response);
                }
            }
            return parseDns(response);
        } finally {
            connection.disconnect();
        }
    }

    private byte[] dnsQuery(String hostname, int type) throws IOException {
        try (ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            int id = new SecureRandom().nextInt(0x10000);
            output.write((id >> 8) & 0xff);
            output.write(id & 0xff);
            output.write(0x01);
            output.write(0x00);
            output.write(0x00);
            output.write(0x01);
            output.write(0x00);
            output.write(0x00);
            output.write(0x00);
            output.write(0x00);
            output.write(0x00);
            output.write(0x00);
            for (String label : hostname.split("\\.")) {
                byte[] bytes = label.getBytes(StandardCharsets.US_ASCII);
                output.write(bytes.length);
                output.write(bytes);
            }
            output.write(0);
            output.write((type >> 8) & 0xff);
            output.write(type & 0xff);
            output.write(0x00);
            output.write(0x01);
            return output.toByteArray();
        }
    }

    private DnsResult parseDns(byte[] bytes) throws IOException {
        if (bytes.length < 12) return DnsResult.EMPTY;
        int offset = readName(bytes, 12).next();
        if (offset + 4 > bytes.length) return DnsResult.EMPTY;
        offset += 4;
        int answers = u16(bytes, 6);
        List<InetAddress> addresses = new ArrayList<>();
        List<String> aliases = new ArrayList<>();
        for (int i = 0; i < answers && offset < bytes.length; i++) {
            Name name = readName(bytes, offset);
            offset = name.next();
            if (offset + 10 > bytes.length) break;
            int type = u16(bytes, offset);
            int clazz = u16(bytes, offset + 2);
            int length = u16(bytes, offset + 8);
            offset += 10;
            if (offset + length > bytes.length) break;
            if (clazz == 1) {
                if (type == 1 && length == 4) {
                    addresses.add(InetAddress.getByAddress(new byte[]{bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3]}));
                } else if (type == 28 && length == 16) {
                    byte[] value = new byte[16];
                    System.arraycopy(bytes, offset, value, 0, value.length);
                    addresses.add(InetAddress.getByAddress(value));
                } else if (type == 5) {
                    aliases.add(stripDot(readName(bytes, offset).value()));
                }
            }
            offset += length;
        }
        return new DnsResult(addresses, aliases);
    }

    private DnsResult parseJson(byte[] bytes) throws IOException {
        JsonObject json = JsonParser.parseString(new String(bytes, StandardCharsets.UTF_8)).getAsJsonObject();
        JsonArray answers = json.has("Answer") ? json.getAsJsonArray("Answer") : new JsonArray();
        List<InetAddress> addresses = new ArrayList<>();
        List<String> aliases = new ArrayList<>();
        for (JsonElement answer : answers) {
            JsonObject value = answer.getAsJsonObject();
            if (!value.has("type") || !value.has("data")) continue;
            int type = value.get("type").getAsInt();
            String data = value.get("data").getAsString();
            if (type == 1 || type == 28) addresses.add(InetAddress.getByName(data));
            else if (type == 5) aliases.add(stripDot(data));
        }
        return new DnsResult(addresses, aliases);
    }

    private Name readName(byte[] bytes, int offset) throws IOException {
        StringBuilder name = new StringBuilder();
        int next = offset;
        boolean jumped = false;
        Set<Integer> visited = new LinkedHashSet<>();
        for (int step = 0; step < 128 && offset < bytes.length; step++) {
            int length = bytes[offset] & 0xff;
            if (length == 0) {
                offset++;
                if (!jumped) next = offset;
                return new Name(name.toString(), next);
            }
            if ((length & 0xc0) == 0xc0) {
                if (offset + 1 >= bytes.length) throw new IOException("Invalid DNS name pointer");
                int pointer = ((length & 0x3f) << 8) | (bytes[offset + 1] & 0xff);
                if (!visited.add(pointer)) throw new IOException("DNS name pointer loop");
                if (!jumped) next = offset + 2;
                jumped = true;
                offset = pointer;
                continue;
            }
            if ((length & 0xc0) != 0 || offset + 1 + length > bytes.length) throw new IOException("Invalid DNS name");
            if (name.length() > 0) name.append('.');
            name.append(new String(bytes, offset + 1, length, StandardCharsets.US_ASCII));
            offset += length + 1;
            if (!jumped) next = offset;
        }
        throw new IOException("Invalid DNS name");
    }

    private int firstNonWhitespace(byte[] bytes) {
        for (int i = 0; i < bytes.length; i++) {
            int value = bytes[i] & 0xff;
            if (value != ' ' && value != '\n' && value != '\r' && value != '\t') return i;
        }
        return -1;
    }

    private String toAscii(String hostname) throws IOException {
        try {
            return IDN.toASCII(stripDot(hostname), IDN.ALLOW_UNASSIGNED).toLowerCase(Locale.ROOT);
        } catch (IllegalArgumentException error) {
            throw new UnknownHostException(hostname);
        }
    }

    private String stripDot(String value) {
        return value.endsWith(".") ? value.substring(0, value.length() - 1) : value;
    }

    private int u16(byte[] bytes, int offset) {
        return ((bytes[offset] & 0xff) << 8) | (bytes[offset + 1] & 0xff);
    }

    private byte[] readBytes(java.io.InputStream input) throws IOException {
        try (ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[4096];
            int count;
            while ((count = input.read(buffer)) != -1) output.write(buffer, 0, count);
            return output.toByteArray();
        }
    }

    private record DnsResult(List<InetAddress> addresses, List<String> aliases) {
        private static final DnsResult EMPTY = new DnsResult(List.of(), List.of());
    }

    private record Name(String value, int next) {
    }
}
