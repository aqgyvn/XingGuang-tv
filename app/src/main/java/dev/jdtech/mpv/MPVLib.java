package dev.jdtech.mpv;

import android.content.Context;
import android.view.Surface;

import com.fongmi.android.tv.App;

import java.util.ArrayList;
import java.util.List;

public final class MPVLib {

    public static final int MPV_EVENT_START_FILE = 6;
    public static final int MPV_EVENT_END_FILE = 7;
    public static final int MPV_EVENT_FILE_LOADED = 8;
    public static final int MPV_EVENT_VIDEO_RECONFIG = 17;
    public static final int MPV_FORMAT_FLAG = 3;
    public static final int MPV_FORMAT_DOUBLE = 5;

    private static final List<Observer> observers = new ArrayList<>();
    private static boolean loaded;

    static {
        try {
            System.loadLibrary("mpv");
            System.loadLibrary("player");
            loaded = true;
        } catch (Throwable e) {
            loaded = false;
        }
    }

    private MPVLib() {
    }

    public static boolean isAvailable() {
        return loaded;
    }

    public static void addObserver(Observer observer) {
        synchronized (observers) {
            if (!observers.contains(observer)) observers.add(observer);
        }
    }

    public static void removeObserver(Observer observer) {
        synchronized (observers) {
            observers.remove(observer);
        }
    }

    public static void event(int event) {
        List<Observer> snapshot;
        synchronized (observers) {
            snapshot = new ArrayList<>(observers);
        }
        for (Observer observer : snapshot) App.post(() -> observer.onEvent(event));
    }

    public static void eventProperty(String name, boolean value) {
        List<Observer> snapshot;
        synchronized (observers) {
            snapshot = new ArrayList<>(observers);
        }
        for (Observer observer : snapshot) App.post(() -> observer.onProperty(name, value));
    }

    public static void eventProperty(String name, double value) {
    }

    public static void eventProperty(String name, long value) {
    }

    public static void eventProperty(String name, String value) {
    }

    public static void eventProperty(String name) {
    }

    public static void logMessage(String prefix, int level, String text) {
    }

    public static native void attachSurface(Surface surface);

    public static native void command(String[] args);

    public static native void create(Context context);

    public static native void destroy();

    public static native void detachSurface();

    public static native Boolean getPropertyBoolean(String name);

    public static native Double getPropertyDouble(String name);

    public static native Integer getPropertyInt(String name);

    public static native String getPropertyString(String name);

    public static native void init();

    public static native void observeProperty(String name, int format);

    public static native int setOptionString(String name, String value);

    public static native void setPropertyBoolean(String name, Boolean value);

    public static native void setPropertyDouble(String name, Double value);

    public static native void setPropertyInt(String name, Integer value);

    public static native void setPropertyString(String name, String value);

    public interface Observer {
        void onEvent(int event);

        default void onProperty(String name, boolean value) {
        }
    }
}
