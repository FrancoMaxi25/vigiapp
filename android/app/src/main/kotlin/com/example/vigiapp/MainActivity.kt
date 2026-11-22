package com.example.vigiapp

import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.vigiapp/speech"
    private var speechRecognizer: SpeechRecognizer? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "iniciarReconocimiento" -> {
                    // Cancela cualquier reconocimiento previo
                    speechRecognizer?.destroy()
                    speechRecognizer = null
                    pendingResult    = result
                    iniciarReconocimiento()
                }
                "detenerReconocimiento" -> {
                    speechRecognizer?.stopListening()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun iniciarReconocimiento() {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            pendingResult?.error(
                "NO_DISPONIBLE",
                "Reconocimiento de voz no disponible en este dispositivo",
                null
            )
            pendingResult = null
            return
        }

        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "es-PE")
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "es")
            putExtra(RecognizerIntent.EXTRA_ONLY_RETURN_LANGUAGE_PREFERENCE, false)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 3000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 2000L)
        }

        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                // Listo para escuchar
            }
            override fun onBeginningOfSpeech() {
                // Empezó a escuchar
            }
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {
                // Terminó de escuchar, procesando...
            }
            override fun onError(error: Int) {
    val mensaje = when (error) {
        SpeechRecognizer.ERROR_NO_MATCH       -> "No se detectó voz"
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Tiempo de espera agotado"
        SpeechRecognizer.ERROR_AUDIO          -> "Error de audio"
        SpeechRecognizer.ERROR_NETWORK        -> "Error de red"
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Tiempo de red agotado"
        SpeechRecognizer.ERROR_CLIENT         -> "Error del cliente"
        SpeechRecognizer.ERROR_SERVER         -> "Error del servidor"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Reconocedor ocupado"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Sin permisos"
        else -> "Error desconocido: $error"
    }
    pendingResult?.error("ERROR_VOZ", mensaje, null)
    pendingResult = null
}
            override fun onResults(bundle: Bundle?) {
                val matches = bundle?.getStringArrayList(
                    SpeechRecognizer.RESULTS_RECOGNITION
                )
                val texto = matches?.firstOrNull() ?: ""
                pendingResult?.success(texto)
                pendingResult = null
            }
            override fun onPartialResults(bundle: Bundle?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        speechRecognizer?.startListening(intent)
    }

    override fun onDestroy() {
        speechRecognizer?.destroy()
        speechRecognizer = null
        super.onDestroy()
    }
}