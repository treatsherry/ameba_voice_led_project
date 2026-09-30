using System;
using System.Diagnostics;
using System.Linq;
using System.IO;
using System.Speech.Recognition;

// Recognition only: this class has no serial-port or LED-control access.
public sealed class SpeechCapture : IDisposable
{
    private SpeechRecognitionEngine engine;
    private readonly Stopwatch elapsed = new Stopwatch();
    private volatile bool finishing;
    private volatile bool cancelRequested;
    public volatile bool Completed;
    public volatile int PeakLevel;
    public volatile int CurrentLevel;
    public volatile bool SpeechDetected;
    public string AudioProblem = "None";
    public string RecordingPath = "";
    public string RecordingError = "";
    public bool RecordingSaved;
    public string Text = "";
    public string Error = "";
    public float Confidence;
    public bool Cancelled;
    public bool IsControlCommand;
    public string ControlCommand = "";
    public double Seconds { get { return elapsed.Elapsed.TotalSeconds; } }

    public void Start(string waveFile)
    {
        var info = SpeechRecognitionEngine.InstalledRecognizers()
            .FirstOrDefault(r => r.Culture.Name == "zh-TW");
        if (info == null) throw new InvalidOperationException("No zh-TW speech recognizer installed.");
        engine = new SpeechRecognitionEngine(info);
        var commands = new Choices("左邊開燈", "右邊開燈");
        var commandBuilder = new GrammarBuilder(commands) { Culture = info.Culture };
        var commandGrammar = new Grammar(commandBuilder) { Name = "LED_COMMANDS", Priority = 10, Weight = 1.0f };
        var dictationGrammar = new DictationGrammar() { Name = "FREE_TEXT", Priority = 0, Weight = 0.35f };
        engine.LoadGrammar(commandGrammar);
        engine.LoadGrammar(dictationGrammar);
        engine.InitialSilenceTimeout = TimeSpan.FromSeconds(7);
        engine.BabbleTimeout = TimeSpan.FromSeconds(7);
        engine.EndSilenceTimeout = TimeSpan.FromMilliseconds(800);
        engine.EndSilenceTimeoutAmbiguous = TimeSpan.FromMilliseconds(1000);
        engine.AudioLevelUpdated += (s, e) => { CurrentLevel = e.AudioLevel; if (e.AudioLevel > PeakLevel) PeakLevel = e.AudioLevel; };
        engine.SpeechDetected += (s, e) => { SpeechDetected = true; };
        engine.AudioSignalProblemOccurred += (s, e) => { AudioProblem = e.AudioSignalProblem.ToString(); };
        engine.SpeechRecognized += (s, e) => {
            if (!cancelRequested) {
                Text = e.Result.Text;
                Confidence = e.Result.Confidence;
                IsControlCommand = e.Result.Grammar != null && e.Result.Grammar.Name == "LED_COMMANDS" && Confidence >= 0.20f;
                if (IsControlCommand) {
                    if (Text == "左邊開燈") ControlCommand = "BLUE_ON";
                    else if (Text == "右邊開燈") ControlCommand = "GREEN_ON";
                    else { IsControlCommand = false; ControlCommand = ""; }
                }
                SaveAudio(e.Result);
            }
        };
        engine.SpeechRecognitionRejected += (s, e) => { if (!cancelRequested) SaveAudio(e.Result); };
        engine.RecognizeCompleted += (s, e) => {
            if (e.Error != null) Error = e.Error.Message;
            // SAPI can report Cancelled even for a requested graceful stop.
            Cancelled = cancelRequested || (e.Cancelled && !finishing);
            if (Cancelled || e.Error != null) { Text = ""; Confidence = 0; }
            if (!Cancelled && e.Error == null && e.Result != null) {
                Text = e.Result.Text;
                Confidence = e.Result.Confidence;
                IsControlCommand = e.Result.Grammar != null && e.Result.Grammar.Name == "LED_COMMANDS" && Confidence >= 0.20f;
                if (IsControlCommand) {
                    if (Text == "左邊開燈") ControlCommand = "BLUE_ON";
                    else if (Text == "右邊開燈") ControlCommand = "GREEN_ON";
                    else { IsControlCommand = false; ControlCommand = ""; }
                }
            }
            elapsed.Stop();
            Completed = true;
        };
        if (String.IsNullOrEmpty(waveFile)) engine.SetInputToDefaultAudioDevice();
        else engine.SetInputToWaveFile(waveFile);
        elapsed.Start();
        engine.RecognizeAsync(RecognizeMode.Single);
    }

    public void Cancel() { if (engine != null && !Completed) { cancelRequested = true; engine.RecognizeAsyncCancel(); } }
    private void SaveAudio(RecognitionResult result)
    {
        if (String.IsNullOrEmpty(RecordingPath) || result == null || result.Audio == null) return;
        try {
            using (var file = File.Create(RecordingPath)) result.Audio.WriteToWaveStream(file);
            RecordingSaved = true;
        } catch (Exception ex) { RecordingError = ex.Message; }
    }
    public void Finish() { if (engine != null && !Completed) { finishing = true; engine.RecognizeAsyncStop(); } }
    public void Dispose()
    {
        if (engine != null) { engine.Dispose(); engine = null; }
    }
}
