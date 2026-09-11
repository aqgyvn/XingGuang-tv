package com.github.catvod.net.spider;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;

public final class XgHeaders {
    private final List<String> names;
    private final List<String> values;

    private XgHeaders(Builder builder) {
        names = List.copyOf(builder.names);
        values = List.copyOf(builder.values);
    }

    public static XgHeaders of(Map<String, String> source) {
        Builder builder = new Builder();
        if (source != null) source.forEach(builder::add);
        return builder.build();
    }

    public String get(String name) {
        for (int i = names.size() - 1; i >= 0; i--) if (names.get(i).equalsIgnoreCase(name)) return values.get(i);
        return null;
    }

    public int size() { return names.size(); }
    public String name(int index) { return names.get(index); }
    public String value(int index) { return values.get(index); }

    public Set<String> names() {
        Set<String> result = new TreeSet<>(String.CASE_INSENSITIVE_ORDER);
        result.addAll(names);
        return Collections.unmodifiableSet(result);
    }

    public List<String> values(String name) {
        List<String> result = new ArrayList<>();
        for (int i = 0; i < names.size(); i++) if (names.get(i).equalsIgnoreCase(name)) result.add(values.get(i));
        return Collections.unmodifiableList(result);
    }

    public Map<String, List<String>> toMultimap() {
        Map<String, List<String>> result = new TreeMap<>(String.CASE_INSENSITIVE_ORDER);
        for (String name : names()) result.put(name, values(name));
        return Collections.unmodifiableMap(result);
    }

    public Builder newBuilder() {
        Builder builder = new Builder();
        builder.names.addAll(names);
        builder.values.addAll(values);
        return builder;
    }

    public static final class Builder {
        private final List<String> names = new ArrayList<>();
        private final List<String> values = new ArrayList<>();

        public Builder add(String name, String value) {
            if (name != null && value != null) {
                names.add(name);
                values.add(value);
            }
            return this;
        }

        public Builder set(String name, String value) {
            return removeAll(name).add(name, value);
        }

        public Builder removeAll(String name) {
            for (int i = names.size() - 1; i >= 0; i--) {
                if (!names.get(i).equalsIgnoreCase(name)) continue;
                names.remove(i);
                values.remove(i);
            }
            return this;
        }

        public XgHeaders build() {
            return new XgHeaders(this);
        }
    }
}
