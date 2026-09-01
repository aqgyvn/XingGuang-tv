package com.github.catvod.net;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public final class XgHeaders {

    private final LinkedHashMap<String, List<String>> values;

    private XgHeaders(Map<String, List<String>> values) {
        this.values = new LinkedHashMap<>();
        values.forEach((name, entries) -> this.values.put(name, List.copyOf(entries)));
    }

    public static XgHeaders of(Map<String, String> headers) {
        Builder builder = new Builder();
        if (headers != null) headers.forEach(builder::set);
        return builder.build();
    }

    public String get(String name) {
        for (Map.Entry<String, List<String>> entry : values.entrySet()) {
            if (entry.getKey().equalsIgnoreCase(name)) return entry.getValue().isEmpty() ? null : entry.getValue().get(entry.getValue().size() - 1);
        }
        return null;
    }

    public Map<String, List<String>> toMultimap() {
        return Collections.unmodifiableMap(values);
    }

    public Builder newBuilder() {
        return new Builder(values);
    }

    public static final class Builder {

        private final LinkedHashMap<String, List<String>> values;

        public Builder() {
            values = new LinkedHashMap<>();
        }

        private Builder(Map<String, List<String>> values) {
            this();
            values.forEach((name, entries) -> this.values.put(name, new ArrayList<>(entries)));
        }

        public Builder set(String name, String value) {
            remove(name);
            return add(name, value);
        }

        public Builder add(String name, String value) {
            if (name == null || value == null) return this;
            values.computeIfAbsent(name, ignored -> new ArrayList<>()).add(value);
            return this;
        }

        private void remove(String name) {
            String match = null;
            for (String item : values.keySet()) if (item.toLowerCase(Locale.ROOT).equals(name.toLowerCase(Locale.ROOT))) {
                match = item;
                break;
            }
            if (match != null) values.remove(match);
        }

        public XgHeaders build() {
            return new XgHeaders(values);
        }
    }
}
