package com.github.catvod.net.webdav;

import org.xml.sax.Attributes;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;
import org.xml.sax.XMLReader;
import org.xml.sax.ext.DefaultHandler2;

import java.io.FilterInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InterruptedIOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.text.ParsePosition;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.TimeZone;

import javax.xml.parsers.ParserConfigurationException;
import javax.xml.parsers.SAXParserFactory;

final class XgDavParser extends DefaultHandler2 {
    private static final int MAX_BYTES = 8 * 1024 * 1024;
    private final URI requested;
    private final Map<String, XgDavResource> resources = new LinkedHashMap<>();
    private final StringBuilder text = new StringBuilder();
    private final String[] elements = new String[65];
    private Response response;
    private Properties properties;
    private int depth;
    private int responses;
    private int failed;

    private XgDavParser(URI requested) { this.requested = requested; }

    static List<XgDavResource> parse(InputStream input, URI requested) throws IOException {
        XgDavParser handler = new XgDavParser(requested);
        try {
            SAXParserFactory factory = SAXParserFactory.newInstance();
            factory.setNamespaceAware(true);
            XMLReader reader = factory.newSAXParser().getXMLReader();
            reader.setFeature("http://xml.org/sax/features/external-general-entities", false);
            reader.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
            reader.setProperty("http://xml.org/sax/properties/lexical-handler", handler);
            reader.setEntityResolver(handler);
            reader.setContentHandler(handler);
            reader.setErrorHandler(handler);
            reader.parse(new InputSource(new BoundedInput(input)));
        } catch (SAXException e) {
            if (e.getException() instanceof IOException cause) throw cause;
            throw new IOException("Invalid WebDAV multistatus XML", e);
        } catch (ParserConfigurationException e) {
            throw new IOException("Creating WebDAV XML parser failed", e);
        }
        if (handler.resources.isEmpty() && handler.failed > 0) throw new IOException("WebDAV returned no readable resources");
        String key = key(requested.getPath());
        XgDavResource self = handler.resources.remove(key);
        // FishDrive removes index zero; keep real children even when servers omit/reorder self.
        if (self == null) self = new XgDavResource(requested.getPath(), true, -1, null);
        List<XgDavResource> result = new ArrayList<>();
        result.add(self);
        result.addAll(handler.resources.values());
        return result;
    }

    @Override public void startElement(String namespace, String name, String qualified, Attributes attributes) throws SAXException {
        if (++depth > 64) throw new SAXException("WebDAV XML exceeds nesting limit");
        elements[depth] = "DAV:".equals(namespace) ? name : null;
        text.setLength(0);
        if (depth == 1 && (!"DAV:".equals(namespace) || !name.equals("multistatus"))) {
            throw new SAXException("Expected DAV:multistatus");
        }
        if (!"DAV:".equals(namespace)) return;
        if (depth == 2 && name.equals("response")) {
            if (++responses > 10000) throw new SAXException("WebDAV directory exceeds resource limit");
            response = new Response();
        }
        if (response == null) return;
        if (depth == 3 && name.equals("propstat")) properties = new Properties();
        if (properties != null && depth == 6 && name.equals("collection")
                && "prop".equals(elements[4]) && "resourcetype".equals(elements[5])) properties.directory = true;
    }

    @Override public void characters(char[] buffer, int offset, int length) throws SAXException {
        if (Thread.currentThread().isInterrupted()) throw new SAXException(new InterruptedIOException("WebDAV parsing interrupted"));
        if (length > 65536 - text.length()) throw new SAXException("WebDAV property exceeds text limit");
        text.append(buffer, offset, length);
    }

    @Override public void endElement(String namespace, String name, String qualified) throws SAXException {
        String value = text.toString().trim();
        if ("DAV:".equals(namespace) && response != null) {
            if (depth == 3 && name.equals("href")) response.href = value;
            if (depth == 3 && name.equals("status")) response.status = status(value);
            if (properties != null) {
                if (depth == 4 && name.equals("status")) properties.status = status(value);
                if (depth == 5 && "prop".equals(elements[4])) {
                    if (name.equals("getcontentlength")) properties.length = length(value);
                    if (name.equals("getlastmodified")) properties.modified = date(value);
                    if (name.equals("getcontenttype") && value.equalsIgnoreCase("httpd/unix-directory")) properties.directory = true;
                }
                if (depth == 3 && name.equals("propstat")) {
                    if (success(properties.status)) {
                        response.readable = true;
                        response.directory |= properties.directory;
                        if (properties.length != null) response.length = properties.length;
                        if (properties.modified != null) response.modified = properties.modified;
                    }
                    properties = null;
                }
            }
            if (depth == 2 && name.equals("response")) {
                finishResponse();
                response = null;
            }
        }
        text.setLength(0);
        depth--;
    }

    private void finishResponse() throws SAXException {
        if (response.href == null || response.href.isEmpty()) throw new SAXException("WebDAV response is missing href");
        URI href;
        try {
            href = requested.resolve(new URI(response.href.replace(" ", "%20"))).normalize();
        } catch (URISyntaxException | IllegalArgumentException e) {
            throw new SAXException("Invalid WebDAV resource href", e);
        }
        if (href.getPath() == null || !href.getPath().startsWith("/")
                || (!"http".equalsIgnoreCase(href.getScheme()) && !"https".equalsIgnoreCase(href.getScheme()))) {
            throw new SAXException("Invalid WebDAV resource path");
        }
        String path = href.getPath();
        if (!success(response.status) || !response.readable) {
            failed++;
            if (key(path).equals(key(requested.getPath()))) throw new SAXException("WebDAV collection properties are not readable");
            return;
        }
        resources.put(key(path), new XgDavResource(path, response.directory || path.endsWith("/"),
                response.length, response.modified));
    }

    @Override public void startDTD(String name, String publicId, String systemId) throws SAXException {
        throw new SAXException("WebDAV XML DTD is disabled");
    }

    @Override public InputSource resolveEntity(String publicId, String systemId) throws SAXException {
        throw new SAXException("WebDAV XML external entities are disabled");
    }

    @Override public void error(org.xml.sax.SAXParseException e) throws SAXException { throw e; }
    @Override public void fatalError(org.xml.sax.SAXParseException e) throws SAXException { throw e; }

    private static boolean success(int code) { return code >= 200 && code < 300; }

    private static int status(String value) {
        String[] parts = value.split("\\s+", 3);
        if (parts.length < 2 || !parts[0].startsWith("HTTP/")) return 0;
        try { return Integer.parseInt(parts[1]); }
        catch (NumberFormatException e) { return 0; }
    }

    private static String key(String path) {
        return path.length() > 1 && path.endsWith("/") ? path.substring(0, path.length() - 1) : path;
    }

    private static Long length(String value) {
        try { return Math.max(-1, Long.parseLong(value)); }
        catch (NumberFormatException e) { return -1L; }
    }

    private static Date date(String value) {
        for (String pattern : new String[]{"EEE, dd MMM yyyy HH:mm:ss zzz", "EEEE, dd-MMM-yy HH:mm:ss zzz",
                "EEE MMM d HH:mm:ss yyyy", "yyyy-MM-dd'T'HH:mm:ss.SSSXXX", "yyyy-MM-dd'T'HH:mm:ssXXX"}) {
            SimpleDateFormat format = new SimpleDateFormat(pattern, Locale.US);
            format.setLenient(false);
            format.setTimeZone(TimeZone.getTimeZone("GMT"));
            ParsePosition position = new ParsePosition(0);
            Date result = format.parse(value, position);
            if (result != null && position.getIndex() == value.length()) return result;
        }
        return null;
    }

    private static final class Response {
        String href;
        int status = 200;
        boolean readable;
        boolean directory;
        long length = -1;
        Date modified;
    }

    private static final class Properties {
        int status;
        boolean directory;
        Long length;
        Date modified;
    }

    private static final class BoundedInput extends FilterInputStream {
        private int total;
        BoundedInput(InputStream input) { super(input); }

        @Override public int read() throws IOException {
            check();
            int value = in.read();
            if (value >= 0) total++;
            check();
            return value;
        }

        @Override public int read(byte[] buffer, int offset, int length) throws IOException {
            check();
            int count = in.read(buffer, offset, Math.min(length, MAX_BYTES - total + 1));
            if (count > 0) total += count;
            check();
            return count;
        }

        private void check() throws IOException {
            if (Thread.currentThread().isInterrupted()) throw new InterruptedIOException("WebDAV parsing interrupted");
            if (total > MAX_BYTES) throw new IOException("WebDAV XML exceeds size limit");
        }
    }
}
