import whisper
public enum BadasseoEngine {
    public static func systemInfo() -> String { String(cString: whisper_print_system_info()) }
}
