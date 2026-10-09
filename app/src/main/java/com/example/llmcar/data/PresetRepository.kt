package com.example.llmcar.data

data class Preset(
    val id: String,
    val displayName: String,
    val prompt: String,
    val voiceTriggers: List<String>,
    val icon: String
)

object PresetRepository {

    val presets = listOf(
        Preset(
            id = "assistant",
            displayName = "Ассистент",
            icon = "Assistant",
            voiceTriggers = listOf("ассистент", "обычный режим", "режим ассистент"),
            prompt = """
Ты — встроенный голосовой ассистент автомобиля. Отвечай кратко: 1–2 предложения,
без вступлений вроде «Конечно!». Язык — русский. Используй доступные инструменты
для данных автомобиля, не выдумывай значения. Никаких длинных списков и markdown.
            """.trimIndent()
        ),
        Preset(
            id = "diagnostic",
            displayName = "Диагност OBD",
            icon = "Build",
            voiceTriggers = listOf("диагност", "режим диагностика", "режим диагноста"),
            prompt = """
Ты — автомобильный диагност. Общайся техническим языком, коротко.
Всегда обращайся к инструментам OBD-II за фактическими данными.
При кодах ошибок (DTC) объясняй причину и что делать.
            """.trimIndent()
        ),
        Preset(
            id = "navigator",
            displayName = "Навигатор",
            icon = "Map",
            voiceTriggers = listOf("навигатор", "режим навигация", "режим навигатор"),
            prompt = """
Ты — навигационный ассистент. Помогаешь строить маршруты, искать адреса.
Используй инструменты navigate_to и open_maps. Отвечай кратко, только по существу.
            """.trimIndent()
        ),
        Preset(
            id = "media",
            displayName = "Медиа",
            icon = "MusicNote",
            voiceTriggers = listOf("медиа", "музыка", "режим музыка", "режим медиа"),
            prompt = """
Ты — медиа-ассистент автомобиля. Управляешь музыкой и медиаплеерами:
media_control, open_app, play_music. Отвечай одной короткой фразой.
            """.trimIndent()
        ),
        Preset(
            id = "free",
            displayName = "Свободный диалог",
            icon = "Forum",
            voiceTriggers = listOf("свободный", "свободный режим", "режим диалог"),
            prompt = """
Ты — дружелюбный собеседник. Отвечай развёрнуто, можешь шутить.
            """.trimIndent()
        )
    )

    val defaultId = "assistant"

    fun byId(id: String): Preset = presets.firstOrNull { it.id == id } ?: presets.first()

    fun matchByVoice(recognized: String, normalize: (String) -> String): Preset? {
        val n = normalize(recognized)
        if (n.isBlank()) return null
        return presets.firstOrNull { p ->
            p.voiceTriggers.any { t ->
                val tt = normalize(t)
                tt.isNotEmpty() && (n == tt || n.contains(tt))
            }
        }
    }
}