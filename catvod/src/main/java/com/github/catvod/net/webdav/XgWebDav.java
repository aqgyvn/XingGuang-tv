package com.github.catvod.net.webdav;

import java.io.IOException;
import java.util.List;

/** The WebDAV contract used by migrated crawlers. */
public interface XgWebDav {
    void setCredentials(String username, String password);
    List<XgDavResource> list(String url) throws IOException;
}
