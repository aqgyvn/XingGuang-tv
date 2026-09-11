package com.fongmi.android.tv.glide;

import androidx.annotation.NonNull;

import com.bumptech.glide.Priority;
import com.bumptech.glide.load.DataSource;
import com.bumptech.glide.load.Options;
import com.bumptech.glide.load.data.DataFetcher;
import com.bumptech.glide.load.model.GlideUrl;
import com.bumptech.glide.load.model.ModelLoader;
import com.bumptech.glide.load.model.ModelLoaderFactory;
import com.bumptech.glide.load.model.MultiModelLoaderFactory;
import com.github.catvod.net.XgCall;
import com.github.catvod.net.XgHttp;
import com.github.catvod.net.XgResponse;

import java.io.IOException;
import java.io.InputStream;

final class XgGlideUrlLoader implements ModelLoader<GlideUrl, InputStream> {

    @Override
    public LoadData<InputStream> buildLoadData(@NonNull GlideUrl model, int width, int height, @NonNull Options options) {
        return new LoadData<>(model, new Fetcher(model));
    }

    @Override
    public boolean handles(@NonNull GlideUrl model) {
        return true;
    }

    static final class Factory implements ModelLoaderFactory<GlideUrl, InputStream> {

        @NonNull
        @Override
        public ModelLoader<GlideUrl, InputStream> build(@NonNull MultiModelLoaderFactory multiFactory) {
            return new XgGlideUrlLoader();
        }

        @Override
        public void teardown() {
        }
    }

    private static final class Fetcher implements DataFetcher<InputStream> {

        private final GlideUrl url;
        private XgCall call;
        private XgResponse response;

        Fetcher(GlideUrl url) {
            this.url = url;
        }

        @Override
        public void loadData(@NonNull Priority priority, @NonNull DataCallback<? super InputStream> callback) {
            try {
                call = XgHttp.call(url.toStringUrl(), url.getHeaders());
                response = call.execute();
                if (!response.isSuccessful()) {
                    IOException error = new IOException("Image request failed: " + response.code() + " " + response.message());
                    cleanup();
                    callback.onLoadFailed(error);
                    return;
                }
                callback.onDataReady(response.body().byteStream());
            } catch (Exception e) {
                cleanup();
                callback.onLoadFailed(e);
            }
        }

        @Override
        public void cleanup() {
            if (response != null) {
                response.close();
                response = null;
            }
        }

        @Override
        public void cancel() {
            if (call != null) call.cancel();
        }

        @NonNull
        @Override
        public Class<InputStream> getDataClass() {
            return InputStream.class;
        }

        @NonNull
        @Override
        public DataSource getDataSource() {
            return DataSource.REMOTE;
        }
    }
}
