package com.github.catvod.net;

import java.io.IOException;
import java.net.HttpURLConnection;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class XgCall {

    private static final ExecutorService DISPATCHER = Executors.newFixedThreadPool(16, runnable -> {
        Thread thread = new Thread(runnable, "XgHttp");
        thread.setDaemon(true);
        return thread;
    });

    private final XgClient client;
    private final XgRequest request;
    private volatile HttpURLConnection connection;
    private volatile boolean canceled;

    XgCall(XgClient client, XgRequest request) {
        this.client = client;
        this.request = request;
    }

    public XgResponse execute() throws IOException {
        if (canceled) throw new IOException("Canceled");
        client.register(this);
        try {
            return XgTransport.execute(this);
        } catch (IOException e) {
            client.unregister(this);
            throw e;
        } catch (RuntimeException e) {
            client.unregister(this);
            throw e;
        }
    }

    public void enqueue(XgCallback callback) {
        DISPATCHER.execute(() -> {
            try {
                callback.onResponse(this, execute());
            } catch (IOException e) {
                callback.onFailure(this, e);
            }
        });
    }

    public void cancel() {
        canceled = true;
        HttpURLConnection current = connection;
        if (current != null) current.disconnect();
    }

    boolean isCanceled() {
        return canceled;
    }

    XgRequest request() {
        return request;
    }

    XgClient client() {
        return client;
    }

    void connection(HttpURLConnection connection) {
        this.connection = connection;
    }
}
