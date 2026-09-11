package com.github.catvod.net.webdav;

import java.util.Date;

public final class XgDavResource {
    private final String path;
    private final boolean directory;
    private final long contentLength;
    private final long modified;

    XgDavResource(String path, boolean directory, long contentLength, Date modified) {
        this.path = path;
        this.directory = directory;
        this.contentLength = contentLength;
        this.modified = modified == null ? 0 : modified.getTime();
    }

    public boolean isDirectory() { return directory; }
    public String getPath() { return path; }
    public Long getContentLength() { return contentLength; }
    public Date getModified() { return new Date(modified); }

    public String getName() {
        String value = path.endsWith("/") ? path.substring(0, path.length() - 1) : path;
        return value.substring(value.lastIndexOf('/') + 1);
    }
}
