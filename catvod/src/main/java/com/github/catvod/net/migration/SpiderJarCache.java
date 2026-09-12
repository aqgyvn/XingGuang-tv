package com.github.catvod.net.migration;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InterruptedIOException;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Locale;
import java.util.zip.ZipFile;

/** Read-only, byte-identical copies: native loaders and signatures see the original archive. */
public final class SpiderJarCache {
    private static final long MAX_BYTES = 256L * 1024 * 1024;

    private SpiderJarCache() {}

    public static synchronized File prepare(File source, File cacheDirectory) throws IOException {
        checkInterrupted();
        if (!source.isFile() || source.length() == 0 || source.length() > MAX_BYTES) {
            throw new IOException("Invalid Spider archive: " + source.getName());
        }
        String suffix = suffix(source);
        String originalHash = sha256(source);
        File directory = cacheDirectory.getCanonicalFile();
        if (!directory.isDirectory() && !directory.mkdirs()) throw new IOException("Creating Spider code cache failed");
        File target = new File(directory, "official-v1-" + originalHash + suffix);
        if (target.isFile() && target.length() == source.length() && originalHash.equals(sha256(target))) {
            if (!target.setReadOnly()) throw new IOException("Setting Spider cache read-only failed");
            return target;
        }
        File temporary = File.createTempFile("spider-", ".tmp", directory);
        try {
            try (InputStream input = new FileInputStream(source); FileOutputStream output = new FileOutputStream(temporary)) {
                // Android 14+: mark dynamically loaded code read-only before filling the open descriptor.
                if (!temporary.setReadOnly()) throw new IOException("Setting Spider staging file read-only failed");
                byte[] buffer = new byte[16384];
                long copied = 0;
                int count;
                while ((count = input.read(buffer)) != -1) {
                    checkInterrupted();
                    copied += count;
                    if (copied > MAX_BYTES) throw new IOException("Spider archive exceeds size limit");
                    output.write(buffer, 0, count);
                }
                output.getFD().sync();
            }
            if (!originalHash.equals(sha256(temporary)) || !originalHash.equals(sha256(source))) {
                throw new IOException("Spider archive changed while preparing code cache");
            }
            checkInterrupted();
            if (target.exists()) {
                target.setWritable(true);
                Files.delete(target.toPath());
            }
            try {
                Files.move(temporary.toPath(), target.toPath(), StandardCopyOption.ATOMIC_MOVE);
            } catch (AtomicMoveNotSupportedException ignored) {
                Files.move(temporary.toPath(), target.toPath());
            }
            return target;
        } finally {
            if (temporary.exists()) {
                temporary.setWritable(true);
                Files.deleteIfExists(temporary.toPath());
            }
        }
    }

    private static String suffix(File source) throws IOException {
        byte[] magic = new byte[8];
        try (InputStream input = new FileInputStream(source)) {
            if (input.read(magic) != magic.length) throw new IOException("Truncated Spider archive");
        }
        if (magic[0] == 'd' && magic[1] == 'e' && magic[2] == 'x' && magic[3] == '\n') return ".dex";
        try (ZipFile zip = new ZipFile(source)) {
            if (zip.getEntry("classes.dex") == null) throw new IOException("Spider archive has no classes.dex");
        }
        return ".jar";
    }

    static String sha256(File file) throws IOException {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            try (InputStream input = new FileInputStream(file)) {
                byte[] buffer = new byte[16384];
                int count;
                while ((count = input.read(buffer)) != -1) {
                    checkInterrupted();
                    digest.update(buffer, 0, count);
                }
            }
            StringBuilder result = new StringBuilder();
            for (byte item : digest.digest()) result.append(String.format(Locale.ROOT, "%02x", item & 0xff));
            return result.toString();
        } catch (NoSuchAlgorithmException error) {
            throw new AssertionError(error);
        }
    }

    private static void checkInterrupted() throws InterruptedIOException {
        if (Thread.currentThread().isInterrupted()) throw new InterruptedIOException("Canceled");
    }
}
