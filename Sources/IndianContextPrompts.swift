// ============================================================
// FILE: Sources/IndianContextPrompts.swift
// FlowKeys — Indian Language & Hinglish Context System
// ============================================================

import Foundation

// MARK: - User Language Mode

enum UserLanguageMode: String, CaseIterable, Codable, Identifiable {
    case hinglish = "hinglish"    // Default for Indian users
    case pureHindi = "hindi"
    case pureEnglish = "english"
    case pureBengali = "bengali"  // Phase 4 — native Bangla script
    case banglish = "banglish"    // Phase 4 — Bengali–English code-switch

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hinglish: return "Hinglish (हिंग्लिश) 🇮🇳"
        case .pureHindi: return "हिंदी (Hindi)"
        case .pureEnglish: return "English"
        case .pureBengali: return "বাংলা (Bengali)"
        case .banglish: return "Banglish (বাংলিশ)"
        }
    }

    /// The Whisper language token to inject into the transcription request.
    /// Research source: Biswas et al. Interspeech 2025 — <|hi|> language
    /// token outperforms <|en|> for Hindi-English code-mix scenarios.
    var whisperLanguageCode: String {
        switch self {
        case .hinglish: return "hi"   // <|hi|> outperforms <|en|> for Hinglish
        case .pureHindi: return "hi"
        case .pureEnglish: return "en"
        case .pureBengali, .banglish: return "bn"
        }
    }

    /// Returns the Whisper prompt string to send with every transcription request.
    /// ALL modes get at minimum the anti-hallucination seed so Whisper's decoder
    /// never hallucinates "Thank you", "Thanks for watching", etc. on short/silent audio.
    func whisperPrompt() -> String {
        switch self {
        case .pureEnglish:
            return ANTI_HALLUCINATION_PRIMER
        case .hinglish, .pureHindi:
            return ANTI_HALLUCINATION_PRIMER + " " + INDIAN_WHISPER_PRIMER
        case .pureBengali, .banglish:
            return ANTI_HALLUCINATION_PRIMER + " " + BENGALI_WHISPER_PRIMER
        }
    }

    /// True for any Indic mode that needs the post-processing addendum.
    var isIndic: Bool { self != .pureEnglish }
}

// MARK: - Anti-Hallucination Primer

/// A short neutral real-speech seed that forces Whisper's beam-search decoder
/// away from its well-known hallucination attractors ("Thank you",
/// "Thanks for watching", "you", "bye", etc.).
///
/// How it works: Whisper's prompt is prepended to the transcript context window.
/// By seeding it with mid-sentence real speech, Whisper's decoder is biased
/// toward continuing real speech rather than defaulting to closing phrases.
///
/// Keep this SHORT (< 50 tokens) so it doesn't eat into the 224-token
/// prompt budget that Whisper allocates.
let ANTI_HALLUCINATION_PRIMER = "Okay so I wanted to say"

// MARK: - Indian Whisper Primer

/// Seeds Whisper's vocabulary decoder with common Hinglish patterns, Indian names,
/// and brand names so that recognition accuracy improves significantly.
/// For Groq/OpenAI Whisper — passed as the `prompt` field in the multipart body.
/// For Gemini — passed as part of the audio understanding prompt.
let INDIAN_WHISPER_PRIMER = """
nमस्ते। यह एक भारतीय उपयोगकर्ता की आवाज़ है। \
The speaker may switch between Hindi and English mid-sentence. \
Common Hinglish patterns: "aaj meeting hai", "please send the report", \
"yaar sun", "bas kar", "kal tak karo", "thoda time do", \
"bilkul sahi", "achha", "theek hai", "haan bhai", "nahi yaar", \
"kya scene hai", "chill kar", "bhai sun", "ekdum sahi", \
"boss ne bola", "client ko bhejdo", "deadline kal hai", \
"paise transfer kar do", "UPI se bhej", "Swiggy order karo", \
"Zepto se mangao", "GPay pe bhej", "NEFT kar do", \
Names: Rahul, Priya, Amit, Neha, Ravi, Sita, Arjun, Kavya, \
Rohan, Pooja, Vijay, Ananya, Suresh, Meera, Kiran, Deepak.
"""

// MARK: - Indian Post-Processing System Prompt Addendum

/// This prompt addendum is appended to the base post-processing system prompt
/// when the user's language mode is set to Hinglish or Pure Hindi.
/// It provides comprehensive rules for handling Hindi-English code-switching,
/// Indian vocabulary, dialects, and context-aware corrections.
let INDIAN_POSTPROCESSING_PROMPT_ADDENDUM = """

═══════════════════════════════════════════════════════
INDIAN LANGUAGE & HINGLISH RULES (ACTIVE)
═══════════════════════════════════════════════════════

LANGUAGE DETECTION & HANDLING RULES:

1. HINGLISH (Code-Switching) — the PRIMARY mode for most Indian users:
   - Hinglish is when the speaker alternates between Hindi and English
     in the same sentence. This is NOT an error. Preserve it exactly.
   - Example RAW: "aaj meeting mein kya discuss hua yaar"
     OUTPUT: "Aaj meeting mein kya discuss hua yaar?"
   - Example RAW: "please send the file by end of day theek hai"
     OUTPUT: "Please send the file by end of day, theek hai?"
   - Example RAW: "bhai sun ye proposal approve ho gaya"
     OUTPUT: "Bhai, sun — ye proposal approve ho gaya."

2. PURE HINDI — when user speaks only in Hindi:
   - Output in Devanagari script if the raw input contains Devanagari
   - Output in Roman-transliterated Hindi if raw input is all Roman
   - Never force a script change. Mirror what the user chose.
   - Correct common Whisper Hindi mistakes:
     * "hain" vs "hai" (plural vs singular verb)
     * "mein" (in) vs "main" (I) — context-dependent
     * "nahi" vs "nahin" — both acceptable, preserve speaker's style
     * "karna" conjugations — don't over-correct
   - Add Devanagari punctuation: । (daṇḍa for sentence end) when
     the full sentence is in Devanagari

3. PURE ENGLISH (Indian accent patterns) — fix these common Whisper errors:
   - "prepone" is a valid Indian English word (antonym of postpone). Keep it.
   - "do the needful" — valid Indian English. Keep it.
   - "revert back" — valid Indian English. Keep it.
   - "out of station" — valid Indian English for "out of town". Keep it.
   - "cousin brother/sister" — valid. Keep it.
   - "good name" (asking someone's name) — valid. Keep it.
   - Fix Whisper's common mishearing of Indian names (see vocabulary below)

═══════════════════════════════════════════════════════
INDIAN VOCABULARY & PROPER NOUNS — ALWAYS SPELL CORRECTLY
═══════════════════════════════════════════════════════

APPS & SERVICES (Indian):
Swiggy, Zomato, Zepto, Blinkit, BigBasket, Meesho, Flipkart,
PhonePe, GPay, Paytm, BHIM, CRED, Razorpay, Nykaa,
Ola, Uber, Rapido, IndiGo, Air India, Vistara, SpiceJet,
Jio, Airtel, BSNL, Vi (Vodafone Idea), JioFiber,
Zerodha, Groww, Upstox, Angel One, HDFC Sky,
BookMyShow, MakeMyTrip, Goibibo, Cleartrip,
Dunzo, Porter, Shiprocket, Delhivery, Ecom Express,
WhatsApp, Instagram, ShareChat, Moj, Josh, Roposo,
IndiaMART, TradeIndia, Amazon.in, Myntra

FINANCIAL & BANKING TERMS:
UPI, NEFT, RTGS, IMPS, EMI, GST, ITR, PAN card,
Aadhaar, DigiLocker, SEBI, NSE, BSE, Sensex, Nifty,
FD (Fixed Deposit), RD (Recurring Deposit), SIP,
mutual fund, demat account, NACH, ECS, CRR, SLR,
cheque bounce, CIBIL score, repo rate, RBI

CITIES & PLACES:
Mumbai, Delhi (not "Dilli" unless user says it), Bengaluru (not Bangalore),
Chennai, Hyderabad, Pune, Kolkata, Ahmedabad, Jaipur, Lucknow,
Chandigarh, Bhopal, Indore, Nagpur, Surat, Coimbatore,
Gurugram (Gurgaon), Noida, Faridabad, Ghaziabad,
Connaught Place, Juhu, Bandra, Andheri, Powai, Whitefield,
Electronic City, Cyber City, DLF, Hinjewadi, Magarpatta,
CP (Connaught Place), BKC (Bandra Kurla Complex),
HITEC City, Koramangala, Indiranagar, HSR Layout

INDIAN NAMES (common Whisper mishearings → correct):
"Rahool" → Rahul | "Krishn" → Krishna | "Aarav" → Aarav
"Vikrant" → Vikrant | "Naman" → Naman | "Harsh" → Harsh
"Siddhant" → Siddhant | "Ayush" → Ayush | "Dhruv" → Dhruv

COMMON TITLES:
ji (respectful suffix — always keep), bhai, didi, uncle, aunty,
sir, ma'am, guruji, panditji, doctor sahab, mantri ji

COMMON ABBREVIATIONS:
BC / OBC / SC / ST — keep as-is (caste categories in Indian context)
IIT / IIM / NIT / AIIMS / IAS / IPS / IFS — keep as acronyms
CA / CS / CMA — keep (professional qualifications)
BJP / INC / AAP / TMC — keep (political parties)
CM / PM / DM / SDM / BDO — keep (govt officials)

═══════════════════════════════════════════════════════
HINGLISH FILLER WORDS & PARTICLES — HANDLING RULES
═══════════════════════════════════════════════════════

ALWAYS REMOVE these pure fillers (no meaning):
matlab (when used as filler only), umm, uh, like (filler),
bas (when used as trailing filler), woh woh woh (repeated)

ALWAYS KEEP these — they carry meaning/tone:
yaar (friend, tone marker), bhai (bro, direct address),
na (right? / isn't it?), na na (no no), haan (yes),
nahi (no), achha (okay/I see), theek hai (alright),
suno / sun (listen), dekho / dekh (look/see),
arre (expression of surprise), oho (realization),
kya yaar (expression of exasperation — keep),
bas bas (enough enough — keep), chal (okay/let's go — keep),
aur (and — keep), toh (so/then — keep),
warna (otherwise — keep), lekin / par (but — keep)

═══════════════════════════════════════════════════════
PUNCTUATION RULES FOR HINGLISH
═══════════════════════════════════════════════════════

- Use English punctuation (. , ? ! —) for Roman/Hinglish text
- Use । for pure Devanagari sentences
- Add commas naturally at breath pauses in Hinglish
- Questions ending in "na?", "hai na?", "theek hai?" → add ?
- Exclamations with "arre!", "yaar!", "wah!" → add !

═══════════════════════════════════════════════════════
CONTEXT-AWARE CORRECTIONS (use app context if provided)
═══════════════════════════════════════════════════════

If context shows user is in: → Apply these rules:

GMAIL / EMAIL:
- Fix email recipient names from context
- Formal closing: "dhanyavaad" → preserve or expand to "Dhanyavaad,"
- Professional Hinglish emails are valid — don't force pure English

WHATSAPP / iMESSAGE:
- Casual tone is correct — don't over-formalize
- Short replies like "haan bhej do", "kal milte hain" → minimal cleanup

TERMINAL / CODE EDITORS:
- If text looks like a code comment or command → do not translate
- Variable names, function names, file paths → never modify

SLACK / TEAMS:
- Semi-formal Hinglish is correct for Indian office culture
- Preserve @mentions and #channels exactly

NOTES / DOCS:
- Standard cleanup, preserve Hindi/Hinglish as spoken

═══════════════════════════════════════════════════════
DIALECT AWARENESS (do NOT force corrections for these)
═══════════════════════════════════════════════════════

These regional speech patterns are CORRECT — preserve them:

DELHI / HARYANA: "kar de", "bata de", "sun le", "chal be", sentence-final "yaar" and "bhai"
MUMBAI (Bambaiya): "kya bol rela hai", "ekdum mast", "bindaas", "bol na", "kar na"
PUNE / MAHARASHTRA: Marathi words mixed in: "kay zalay?", "hou de", "chala"
BENGALURU / SOUTH INDIA: "kya hua re", "aane do", English words inserted more frequently
UP / BIHAR: "hum" instead of "main" (I), "ka" instead of "kya" — valid
GUJARATI-HINDI: Sentence-final "che", "shu" (what) — valid

═══════════════════════════════════════════════════════
OUTPUT FORMAT RULES
═══════════════════════════════════════════════════════

- Return ONLY the cleaned text. No explanation, no labels.
- If transcription is empty or only noise: return exactly: EMPTY
- Never add content the speaker did not say
- Never translate Hindi to English or English to Hindi unless user
  explicitly said "translate this"
- If the raw text is completely unintelligible: return exactly: UNCLEAR

═══════════════════════════════════════════════════════
INDIAN GEN Z TERMS (preserve as-is, never "correct")
═══════════════════════════════════════════════════════

Slay, no cap, lowkey, highkey, vibe check, it's giving,
understood (as affirmation), periodt, main character energy,
touch grass, rent-free, based, NPC behavior, L take, W move,
rizz, gyat, delulu, situationship, ghosting, breadcrumbing,
era (I'm in my X era), it do be like that, valid, mid, bussin,
sus, lowkey obsessed, unalive (careful — contextual),
caught in 4K, living rent free, ratio'd, the algorithm,
shifting, manifestation, that's so real, ick, slay queen

═══════════════════════════════════════════════════════
INDIAN MILLENNIAL TERMS (preserve)
═══════════════════════════════════════════════════════

FOMO, YOLO, bestie, bae, on fleek, goals, squad, lit,
adulting, ghosted, vibe, hustle, grind, side hustle,
literally (used for emphasis), basically, I can't even,
TBH, NGL, low-key, real talk, no shade, shade,
spill the tea, salty, extra, bougie, woke, cancelled,
Netflix and chill, ship (relationships), OTP, endgame

═══════════════════════════════════════════════════════
INDIAN OFFICE / CORPORATE SLANG (preserve + understand)
═══════════════════════════════════════════════════════

EOD (end of day), COB (close of business), WFH, WFO,
hybrid, bandwidth (= time/capacity), loop me in,
sync up, take it offline, circle back, deep dive,
ideate, leverage, pivot, scale, disrupt, ecosystem,
booked and busy, on a call, stepping away, OOO,
appraisal cycle, PIP, townhall, skip-level,
CTC, in-hand, variable, joining bonus, notice period,
cab facility, meal allowance, flexi-timing

═══════════════════════════════════════════════════════
SMS / CHAT ABBREVIATIONS — HANDLING RULES
═══════════════════════════════════════════════════════

UNDERSTAND these abbreviations:
u/ur = you/your | r = are | k/kk = okay |
tmrw = tomorrow | 2day = today | 4 = for |
gtg = got to go | brb = be right back |
bbl = be back later | afk = away from keyboard |
omw = on my way | eta = estimated time of arrival |
np = no problem | nw = no worries | ty/tq = thank you |
ym = you're welcome | ikr = I know right |
smh = shaking my head | tbh = to be honest |
ngl = not gonna lie | idk = I don't know |
imo/imho = in my (humble) opinion | fwiw = for what it's worth |
lmk = let me know | hmu = hit me up | dm = direct message |
irl = in real life | fml = (keep for casual contexts) |
lmao/lol/rofl = keep as-is | wtf/omg = keep as-is |
rn = right now | asap = as soon as possible |
gg = good game | gl = good luck | ez = easy

RULE: In Casual/Chat contexts, if user SPOKE an abbreviation
(e.g., literally said "brb" or "lol"), PRESERVE IT.
In Professional/Email contexts, EXPAND: brb → "be right back", etc.
NEVER expand these (they are mainstream): omg, lol, lmao, lmk, rn, asap.
"""
