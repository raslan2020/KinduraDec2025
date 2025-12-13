"""
Language configuration module for Kindura AI agent.
Provides modular language settings for STT, TTS, and LLM configurations.
"""

from dataclasses import dataclass
from typing import Dict, Any, Optional
from livekit.plugins import deepgram, openai


@dataclass
class LanguageConfig:
    """Configuration for a specific language."""
    code: str
    name: str
    stt_provider: str  # "deepgram" or "openai"
    tts_provider: str  # "deepgram" or "openai"
    stt_options: Dict[str, Any]
    tts_options: Dict[str, Any]
    greeting_template: str
    language_instruction: str = ""
    

class LanguageManager:
    """Manages language configurations for the agent."""
    
    def __init__(self):
        self.languages = self._initialize_languages()
    
    def _initialize_languages(self) -> Dict[str, LanguageConfig]:
        """Initialize all supported language configurations."""
        return {
            "en": LanguageConfig(
                code="en",
                name="English",
                stt_provider="deepgram",
                tts_provider="deepgram",
                stt_options={},
                tts_options={},
                greeting_template="Hello, how are you doing today?, {patient_name}"
            ),
            
            "ar": LanguageConfig(
                code="ar",
                name="Arabic",
                stt_provider="openai",
                tts_provider="openai",
                stt_options={"model": "whisper-1", "language": "ar"},
                tts_options={"model": "tts-1", "voice": "alloy"},
                greeting_template="مرحبا {patient_name}، كيف حالك اليوم؟",
                language_instruction="\n\nIMPORTANT: You MUST respond in Arabic. Use a friendly, conversational tone.\n"
            ),
            
            "ar-LB": LanguageConfig(
                code="ar-LB",
                name="Arabic (Lebanese)",
                stt_provider="openai",
                tts_provider="openai",
                stt_options={"model": "whisper-1", "language": "ar"},
                tts_options={"model": "tts-1", "voice": "alloy"},
                greeting_template="مرحبا {patient_name}، كيفك اليوم؟",
                language_instruction="""
\n\nCRITICAL: You MUST respond ONLY in Lebanese Arabic dialect. Examples:
- Say 'كيفك' not 'كيف حالك'
- Say 'شو' not 'ما' or 'ماذا'
- Say 'هلق' not 'الآن'
- Say 'مبلا' not 'بلى'
- Say 'إيه' not 'نعم'
- Use Lebanese words like: بدي، معليش، يعطيك العافية، شو فيك، وينك
NEVER use formal Arabic (الفصحى). Speak like a Lebanese person would speak casually.\n"""
            ),
            
            "es": LanguageConfig(
                code="es",
                name="Spanish",
                stt_provider="deepgram",
                tts_provider="deepgram",
                stt_options={"language": "es"},
                tts_options={},
                greeting_template="Hola {patient_name}, ¿cómo estás hoy?",
                language_instruction="\n\nIMPORTANT: You MUST respond in Spanish. Use a friendly, conversational tone.\n"
            ),
            
            "fr": LanguageConfig(
                code="fr",
                name="French",
                stt_provider="deepgram",
                tts_provider="deepgram",
                stt_options={"language": "fr"},
                tts_options={},
                greeting_template="Bonjour {patient_name}, comment allez-vous aujourd'hui?",
                language_instruction="\n\nIMPORTANT: You MUST respond in French. Use a friendly, conversational tone.\n"
            ),
            
            "de": LanguageConfig(
                code="de",
                name="German",
                stt_provider="deepgram",
                tts_provider="deepgram",
                stt_options={"language": "de"},
                tts_options={},
                greeting_template="Hallo {patient_name}, wie geht es Ihnen heute?",
                language_instruction="\n\nIMPORTANT: You MUST respond in German. Use a friendly, conversational tone.\n"
            ),
            
            "it": LanguageConfig(
                code="it",
                name="Italian",
                stt_provider="deepgram",
                tts_provider="deepgram",
                stt_options={"language": "it"},
                tts_options={},
                greeting_template="Ciao {patient_name}, come stai oggi?",
                language_instruction="\n\nIMPORTANT: You MUST respond in Italian. Use a friendly, conversational tone.\n"
            ),
            
            "pt": LanguageConfig(
                code="pt",
                name="Portuguese",
                stt_provider="deepgram",
                tts_provider="deepgram",
                stt_options={"language": "pt"},
                tts_options={},
                greeting_template="Olá {patient_name}, como você está hoje?",
                language_instruction="\n\nIMPORTANT: You MUST respond in Portuguese. Use a friendly, conversational tone.\n"
            ),
            
            "ru": LanguageConfig(
                code="ru",
                name="Russian",
                stt_provider="deepgram",
                tts_provider="deepgram",
                stt_options={"language": "ru"},
                tts_options={},
                greeting_template="Здравствуйте {patient_name}, как вы себя чувствуете сегодня?",
                language_instruction="\n\nIMPORTANT: You MUST respond in Russian. Use a friendly, conversational tone.\n"
            ),
            
            "zh": LanguageConfig(
                code="zh",
                name="Chinese",
                stt_provider="deepgram",
                tts_provider="deepgram",
                stt_options={"language": "zh"},
                tts_options={},
                greeting_template="你好 {patient_name}，你今天怎么样？",
                language_instruction="\n\nIMPORTANT: You MUST respond in Chinese. Use a friendly, conversational tone.\n"
            ),
            
            "ja": LanguageConfig(
                code="ja",
                name="Japanese",
                stt_provider="deepgram",
                tts_provider="deepgram",
                stt_options={"language": "ja"},
                tts_options={},
                greeting_template="こんにちは {patient_name}さん、今日はいかがですか？",
                language_instruction="\n\nIMPORTANT: You MUST respond in Japanese. Use a friendly, conversational tone.\n"
            ),
            
            "ko": LanguageConfig(
                code="ko",
                name="Korean",
                stt_provider="deepgram",
                tts_provider="deepgram",
                stt_options={"language": "ko"},
                tts_options={},
                greeting_template="안녕하세요 {patient_name}님, 오늘 어떠세요?",
                language_instruction="\n\nIMPORTANT: You MUST respond in Korean. Use a friendly, conversational tone.\n"
            ),
            
            "hi": LanguageConfig(
                code="hi",
                name="Hindi",
                stt_provider="deepgram",
                tts_provider="deepgram",
                stt_options={"language": "hi"},
                tts_options={},
                greeting_template="नमस्ते {patient_name}, आज आप कैसे हैं?",
                language_instruction="\n\nIMPORTANT: You MUST respond in Hindi. Use a friendly, conversational tone.\n"
            ),
        }
    
    def get_language_config(self, language_code: str) -> Optional[LanguageConfig]:
        """Get configuration for a specific language."""
        return self.languages.get(language_code, self.languages["en"])
    
    def get_stt_engine(self, language_code: str):
        """Get the STT engine for a specific language."""
        config = self.get_language_config(language_code)
        
        if config.stt_provider == "openai":
            return openai.STT(**config.stt_options)
        elif config.stt_provider == "deepgram":
            if config.stt_options:
                return deepgram.STT(**config.stt_options)
            else:
                return deepgram.STT(language=language_code)
        else:
            # Default to Deepgram
            return deepgram.STT()
    
    def get_tts_engine(self, language_code: str):
        """Get the TTS engine for a specific language."""
        config = self.get_language_config(language_code)
        
        if config.tts_provider == "openai":
            return openai.TTS(**config.tts_options)
        elif config.tts_provider == "deepgram":
            if config.tts_options:
                return deepgram.TTS(**config.tts_options)
            else:
                return deepgram.TTS()
        else:
            # Default to Deepgram
            return deepgram.TTS()
    
    def get_greeting(self, language_code: str, patient_name: str) -> str:
        """Get the greeting message for a specific language."""
        config = self.get_language_config(language_code)
        return config.greeting_template.format(patient_name=patient_name)
    
    def get_language_instruction(self, language_code: str) -> str:
        """Get the language instruction for the LLM prompt."""
        config = self.get_language_config(language_code)
        return config.language_instruction
    
    def add_language(self, config: LanguageConfig):
        """Add or update a language configuration."""
        self.languages[config.code] = config
    
    def get_supported_languages(self) -> Dict[str, str]:
        """Get a dictionary of supported language codes and names."""
        return {code: config.name for code, config in self.languages.items()}