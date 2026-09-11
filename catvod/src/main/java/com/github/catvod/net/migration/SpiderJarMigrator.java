package com.github.catvod.net.migration;

import com.android.tools.smali.dexlib2.Opcode;
import com.android.tools.smali.dexlib2.dexbacked.DexBackedDexFile;
import com.android.tools.smali.dexlib2.iface.DexFile;
import com.android.tools.smali.dexlib2.iface.instruction.Instruction;
import com.android.tools.smali.dexlib2.iface.instruction.ReferenceInstruction;
import com.android.tools.smali.dexlib2.iface.instruction.OneRegisterInstruction;
import com.android.tools.smali.dexlib2.iface.reference.FieldReference;
import com.android.tools.smali.dexlib2.iface.reference.MethodReference;
import com.android.tools.smali.dexlib2.iface.reference.StringReference;
import com.android.tools.smali.dexlib2.iface.reference.TypeReference;
import com.android.tools.smali.dexlib2.iface.value.EncodedValue;
import com.android.tools.smali.dexlib2.iface.value.StringEncodedValue;
import com.android.tools.smali.dexlib2.immutable.instruction.ImmutableInstruction21c;
import com.android.tools.smali.dexlib2.immutable.instruction.ImmutableInstruction31c;
import com.android.tools.smali.dexlib2.immutable.reference.ImmutableStringReference;
import com.android.tools.smali.dexlib2.immutable.value.ImmutableStringEncodedValue;
import com.android.tools.smali.dexlib2.rewriter.DexRewriter;
import com.android.tools.smali.dexlib2.rewriter.EncodedValueRewriter;
import com.android.tools.smali.dexlib2.rewriter.InstructionRewriter;
import com.android.tools.smali.dexlib2.rewriter.MethodReferenceRewriter;
import com.android.tools.smali.dexlib2.rewriter.Rewriter;
import com.android.tools.smali.dexlib2.rewriter.RewriterModule;
import com.android.tools.smali.dexlib2.rewriter.Rewriters;
import com.android.tools.smali.dexlib2.writer.io.MemoryDataStore;
import com.android.tools.smali.dexlib2.writer.pool.DexPool;

import java.io.BufferedInputStream;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FilterOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InterruptedIOException;
import java.io.OutputStream;
import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Enumeration;
import java.util.Locale;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import java.util.zip.ZipOutputStream;

/** Relocates published Spider bytecode onto the project-owned network ABI. */
public final class SpiderJarMigrator {
    private static final String VERSION = "v2";
    private static final int MAX_DEX_BYTES = 64 * 1024 * 1024;
    private static final long MAX_ARCHIVE_BYTES = 256L * 1024 * 1024;

    private SpiderJarMigrator() {}

    public static synchronized File prepare(File source, File cacheDirectory) throws IOException {
        if (!source.isFile() || source.length() == 0 || source.length() > MAX_ARCHIVE_BYTES) {
            throw new IOException("Invalid Spider archive: " + source);
        }
        File directory = cacheDirectory.getCanonicalFile();
        if (!directory.isDirectory() && !directory.mkdirs()) throw new IOException("Creating Spider code cache failed");
        String sourceHash = sha256(source);
        File target = new File(directory, VERSION + "-" + sourceHash + ".jar");
        File checksum = new File(directory, target.getName() + ".sha256");
        if (validCache(target, checksum)) {
            makeReadOnly(target);
            return target;
        }
        File temporary = File.createTempFile("xg-spider-", ".tmp", directory);
        File temporaryHash = File.createTempFile("xg-spider-", ".sha256.tmp", directory);
        try {
            // Open first, then mark read-only before populating dynamically loaded code.
            try (FileOutputStream output = new FileOutputStream(temporary)) {
                makeReadOnly(temporary);
                convert(source, output);
                output.getFD().sync();
            }
            if (!sourceHash.equals(sha256(source))) throw new IOException("Spider source changed during conversion");
            try (FileOutputStream output = new FileOutputStream(temporaryHash)) {
                output.write(sha256(temporary).getBytes(StandardCharsets.US_ASCII));
                output.getFD().sync();
            }
            replace(temporary, target);
            replace(temporaryHash, checksum);
            makeReadOnly(target);
            return target;
        } catch (RuntimeException e) {
            throw new IOException("Spider DEX conversion failed: " + source.getName(), e);
        } finally {
            removeTemporary(temporary);
            removeTemporary(temporaryHash);
        }
    }

    private static boolean validCache(File target, File checksum) throws IOException {
        if (!target.isFile() || !checksum.isFile() || checksum.length() != 64) return false;
        String expected = new String(Files.readAllBytes(checksum.toPath()), StandardCharsets.US_ASCII);
        return sha256(target).equals(expected);
    }

    private static void convert(File source, OutputStream output) throws IOException {
        try (BufferedInputStream input = new BufferedInputStream(new FileInputStream(source))) {
            input.mark(4);
            boolean rawDex = input.read() == 'd' && input.read() == 'e' && input.read() == 'x' && input.read() == '\n';
            input.reset();
            if (rawDex) {
                try (ZipOutputStream zip = zipOutput(output)) {
                    ZipEntry entry = new ZipEntry("classes.dex");
                    entry.setTime(0);
                    zip.putNextEntry(entry);
                    zip.write(rewriteDex(readBounded(input, MAX_DEX_BYTES)));
                    zip.closeEntry();
                }
                return;
            }
        }
        int dexCount = 0;
        long totalBytes = 0;
        try (ZipFile input = new ZipFile(source); ZipOutputStream zip = zipOutput(output)) {
            Enumeration<? extends ZipEntry> entries = input.entries();
            while (entries.hasMoreElements()) {
                checkInterrupted();
                ZipEntry entry = entries.nextElement();
                if (signatureEntry(entry.getName())) continue;
                ZipEntry copy = new ZipEntry(entry.getName());
                copy.setTime(entry.getTime() < 0 ? 0 : entry.getTime());
                zip.putNextEntry(copy);
                if (!entry.isDirectory()) {
                    try (InputStream stream = input.getInputStream(entry)) {
                        if (dexEntry(entry.getName())) {
                            byte[] dex = readBounded(stream, MAX_DEX_BYTES);
                            totalBytes += dex.length;
                            zip.write(rewriteDex(dex));
                            dexCount++;
                        } else {
                            totalBytes += copyBounded(stream, zip, MAX_ARCHIVE_BYTES - totalBytes);
                        }
                    }
                }
                if (totalBytes > MAX_ARCHIVE_BYTES) throw new IOException("Spider archive exceeds expanded size limit");
                zip.closeEntry();
            }
            if (dexCount == 0) throw new IOException("Spider archive contains no classes.dex");
        }
    }

    private static ZipOutputStream zipOutput(OutputStream output) {
        return new ZipOutputStream(new FilterOutputStream(output) {
            @Override public void close() throws IOException { flush(); }
        });
    }

    static boolean dexEntry(String name) {
        return name.matches("classes(?:[2-9]|[1-9][0-9]+)?\\.dex");
    }

    private static boolean signatureEntry(String name) {
        String upper = name.toUpperCase(Locale.ROOT);
        if (!upper.startsWith("META-INF/")) return false;
        String leaf = upper.substring("META-INF/".length());
        return !leaf.contains("/") && (leaf.endsWith(".SF") || leaf.endsWith(".RSA")
                || leaf.endsWith(".DSA") || leaf.endsWith(".EC") || leaf.startsWith("SIG-"));
    }

    static byte[] rewriteDex(byte[] bytes) throws IOException {
        DexBackedDexFile source = DexBackedDexFile.fromInputStream(null, new ByteArrayInputStream(bytes));
        validateNetworkAbi(source);
        DexRewriter rewriter = new DexRewriter(new RewriterModule() {
            @Override
            public Rewriter<String> getTypeRewriter(Rewriters rewriters) {
                return SpiderNetworkTypes::rewrite;
            }

            @Override
            public Rewriter<MethodReference> getMethodReferenceRewriter(Rewriters rewriters) {
                return new MethodReferenceRewriter(rewriters) {
                    @Override public MethodReference rewrite(MethodReference method) {
                        return super.rewrite(SpiderNetworkTypes.hostBridge(method));
                    }
                };
            }

            @Override
            public Rewriter<Instruction> getInstructionRewriter(Rewriters rewriters) {
                return new InstructionRewriter(rewriters) {
                    @Override public Instruction rewrite(Instruction instruction) {
                        Opcode opcode = instruction.getOpcode();
                        if (opcode == Opcode.CONST_STRING || opcode == Opcode.CONST_STRING_JUMBO) {
                            StringReference reference = (StringReference) ((ReferenceInstruction) instruction).getReference();
                            String value = SpiderNetworkTypes.rewriteString(reference.getString());
                            int register = ((OneRegisterInstruction) instruction).getRegisterA();
                            return opcode == Opcode.CONST_STRING
                                    ? new ImmutableInstruction21c(opcode, register, new ImmutableStringReference(value))
                                    : new ImmutableInstruction31c(opcode, register, new ImmutableStringReference(value));
                        }
                        return super.rewrite(instruction);
                    }
                };
            }

            @Override
            public Rewriter<EncodedValue> getEncodedValueRewriter(Rewriters rewriters) {
                return new EncodedValueRewriter(rewriters) {
                    @Override public EncodedValue rewrite(EncodedValue value) {
                        if (value instanceof StringEncodedValue) {
                            return new ImmutableStringEncodedValue(SpiderNetworkTypes.rewriteString(((StringEncodedValue) value).getValue()));
                        }
                        return super.rewrite(value);
                    }
                };
            }
        });
        DexFile rewritten = rewriter.getDexFileRewriter().rewrite(source);
        MemoryDataStore store = new MemoryDataStore();
        try {
            DexPool.writeTo(store, rewritten);
            byte[] result = store.getData();
            DexBackedDexFile verified = DexBackedDexFile.fromInputStream(null, new ByteArrayInputStream(result));
            for (TypeReference type : verified.getTypeReferences()) {
                if (SpiderNetworkTypes.legacy(type.getType())) throw new IOException("Unconverted network type: " + type.getType());
            }
            return result;
        } finally {
            store.close();
        }
    }

    static void validateNetworkAbi(DexBackedDexFile dex) throws IOException {
        for (TypeReference type : dex.getTypeReferences()) {
            if (SpiderNetworkTypes.legacy(type.getType())) resolve(type.getType());
        }
        for (MethodReference original : dex.getMethodSection()) {
            MethodReference method = SpiderNetworkTypes.hostBridge(original);
            if (!SpiderNetworkTypes.legacy(original.getDefiningClass()) && method == original) continue;
            try {
                Class<?> owner = resolve(method.getDefiningClass());
                Class<?>[] parameters = new Class<?>[method.getParameterTypes().size()];
                for (int i = 0; i < parameters.length; i++) parameters[i] = resolve(method.getParameterTypes().get(i).toString());
                if (method.getName().equals("<init>")) owner.getConstructor(parameters);
                else {
                    Method actual = owner.getMethod(method.getName(), parameters);
                    if (actual.getReturnType() != resolve(method.getReturnType())) throw new NoSuchMethodException("Return type mismatch");
                }
            } catch (ReflectiveOperationException | LinkageError e) {
                throw new IOException("Unsupported Spider network method: " + original, e);
            }
        }
        for (FieldReference field : dex.getFieldSection()) {
            if (!SpiderNetworkTypes.legacy(field.getDefiningClass())) continue;
            try {
                if (resolve(field.getDefiningClass()).getField(field.getName()).getType() != resolve(field.getType())) {
                    throw new NoSuchFieldException("Field type mismatch");
                }
            } catch (ReflectiveOperationException | LinkageError e) {
                throw new IOException("Unsupported Spider network field: " + field, e);
            }
        }
    }

    private static Class<?> resolve(String descriptor) throws IOException {
        String type = SpiderNetworkTypes.rewrite(descriptor);
        if (SpiderNetworkTypes.legacy(type)) throw new IOException("Unsupported Spider network type: " + descriptor);
        switch (type) {
            case "V": return void.class;
            case "Z": return boolean.class;
            case "B": return byte.class;
            case "C": return char.class;
            case "S": return short.class;
            case "I": return int.class;
            case "J": return long.class;
            case "F": return float.class;
            case "D": return double.class;
            default:
                try {
                    String name = type.startsWith("[") ? type.replace('/', '.') : SpiderNetworkTypes.binaryName(type);
                    return Class.forName(name, false, SpiderJarMigrator.class.getClassLoader());
                } catch (ClassNotFoundException | LinkageError e) {
                    throw new IOException("Missing Spider network API: " + descriptor, e);
                }
        }
    }

    private static byte[] readBounded(InputStream input, int limit) throws IOException {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        copyBounded(input, output, limit);
        return output.toByteArray();
    }

    private static long copyBounded(InputStream input, OutputStream output, long limit) throws IOException {
        byte[] buffer = new byte[16384];
        long total = 0;
        int count;
        while ((count = input.read(buffer)) != -1) {
            checkInterrupted();
            total += count;
            if (total > limit) throw new IOException("Spider entry exceeds size limit");
            output.write(buffer, 0, count);
        }
        return total;
    }

    public static String sha256(File file) throws IOException {
        try (InputStream input = new FileInputStream(file)) {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] buffer = new byte[16384];
            int count;
            while ((count = input.read(buffer)) != -1) {
                checkInterrupted();
                digest.update(buffer, 0, count);
            }
            StringBuilder result = new StringBuilder(64);
            for (byte value : digest.digest()) {
                result.append(Character.forDigit((value >>> 4) & 15, 16));
                result.append(Character.forDigit(value & 15, 16));
            }
            return result.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new AssertionError(e);
        }
    }

    private static void checkInterrupted() throws InterruptedIOException {
        if (Thread.currentThread().isInterrupted()) throw new InterruptedIOException("Spider conversion interrupted");
    }

    private static void makeReadOnly(File file) throws IOException {
        if (!file.setReadOnly()) throw new IOException("Setting Spider code read-only failed: " + file.getName());
    }

    private static void replace(File temporary, File target) throws IOException {
        if (target.exists()) target.setWritable(true);
        try {
            Files.move(temporary.toPath(), target.toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
        } catch (AtomicMoveNotSupportedException e) {
            Files.move(temporary.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING);
        }
    }

    private static void removeTemporary(File file) throws IOException {
        if (!file.exists()) return;
        file.setWritable(true);
        Files.deleteIfExists(file.toPath());
    }
}
