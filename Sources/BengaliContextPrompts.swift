// ============================================================
// FILE: Sources/BengaliContextPrompts.swift
// FlowKeys — Bengali Language & Banglish Context System (Phase 4)
//
// Mirrors IndianContextPrompts.swift for Bengali. Kept lean: language rules
// + a small relevant vocabulary, not a mega-list (the user dictionary and
// app context carry the rest).
// ============================================================

import Foundation

// MARK: - Bengali Whisper Primer

/// Seeds Whisper's decoder for Bengali / Banglish speech. Sent as the `prompt`
/// field for whisper.cpp / Groq, and folded into the Gemini audio prompt.
let BENGALI_WHISPER_PRIMER = """
নমস্কার। এটি একজন বাংলা ভাষী ব্যক্তির কণ্ঠস্বর। \
The speaker may switch between Bengali and English mid-sentence. \
Common Banglish patterns: "aaj office ache", "please report ta pathao", \
"kal shokale kaj ache", "ektu shomoy dao", "thik ache", "accha", "hae", "na re", \
"ki obostha", "bhai shon", "ki hocche", "ekdom thik", "boss bolechen", \
"client ke pathao", "deadline kal", "taka transfer koro", "bKash e pathao", \
"Nagad diye pathao", "Pathao te ashbo", "Foodpanda te order koro". \
Names: Rahim, Karim, Fatima, Ayesha, Sumon, Rina, Arif, Nusrat, \
Tanvir, Sabrina, Rakib, Mitu, Shuvo, Priya, Hasan, Farhana.
"""

// MARK: - Bengali Post-Processing Addendum

/// Appended to the base post-processing system prompt when the language mode
/// is Bengali or Banglish. Provides code-switching, script, punctuation and
/// vocabulary rules.
let BENGALI_POSTPROCESSING_PROMPT_ADDENDUM = """

═══════════════════════════════════════════════════════
BENGALI & BANGLISH RULES (ACTIVE)
═══════════════════════════════════════════════════════

LANGUAGE & SCRIPT:

1. BANGLISH (code-switching) — the speaker alternates Bengali and English in one
   sentence. This is NOT an error. Preserve it exactly.
   - RAW "aaj client meeting e ki discuss holo re"
     OUT "Aaj client meeting e ki discuss holo re?"
   - RAW "please file ta end of day er moddhe pathao thik ache"
     OUT "Please file ta end of day er moddhe pathao, thik ache?"

2. PURE BENGALI — when the speaker uses only Bengali:
   - Output in Bangla script (Unicode) when the raw input is Bangla script.
   - Output in Roman-transliterated Bengali when the raw input is all Roman.
   - Never force a script change unless the OUTPUT_SCRIPT contract says so.
   - Sentence-ending punctuation: use "।" (daṛi) for full Bangla sentences,
     "?" and "!" as normal.
   - Common Whisper Bengali fixes:
     * "ache" vs "achhe" — keep the speaker's spelling
     * "hoye" / "hoe" / "hoye geche" — don't over-correct
     * "ki" (what / question particle) vs "ki" (whether) — context-dependent
     * "na" (no) vs "-na" (verb negation suffix) — keep as spoken

3. ROMAN BENGALI standard spellings (use when writing Roman):
   ami, tumi, apni, tui, se, amra, tomra, tara,
   korchi, korbo, korechi, hocche, hobe, hoyeche,
   kal, aaj, ekhon, tarpor, karon, kintu, tobe, ba, ar,
   bhai, dada, didi, apu, mama, khala, chacha (relations / address — keep).

═══════════════════════════════════════════════════════
BENGALI APPS, SERVICES & TERMS — SPELL CORRECTLY
═══════════════════════════════════════════════════════

PAYMENTS / FINTECH (Bangladesh + WB):
bKash, Nagad, Rocket, Upay, TAP, SureCash, DBBL, Pathao Pay,
NPSB, EFT, RTGS, MFS, TIN, NID, e-TIN, VAT, AIT.

DELIVERY / RIDE / COMMERCE:
Pathao, Uber, Shohoz, Obhai, Daraz, Chaldal, Foodpanda, Sheba.xyz,
Rokomari, Priyoshop, AjkerDeal, Evaly, Shwapno, Meena Bazar, Agora.

TELECOM: Grameenphone (GP), Robi, Banglalink, Teletalk, Airtel BD.

PLACES: Dhaka, Chattogram (Chittagong), Sylhet, Khulna, Rajshahi, Barishal,
Rangpur, Mymensingh, Gulshan, Banani, Dhanmondi, Uttara, Mirpur, Motijheel,
Kolkata, Howrah, Salt Lake, New Town, Park Street, Esplanade.

INSTITUTIONS: BUET, DU, RUET, KUET, BCS, ACC, NBR, BB (Bangladesh Bank),
BSEC, DSE, CSE, RAB, BGB.

═══════════════════════════════════════════════════════
FILLERS & PARTICLES
═══════════════════════════════════════════════════════

REMOVE (pure fillers): umm, uh, mane (when used as filler only), yani,
ইয়ে, এ্যা, উম.

KEEP (carry meaning / tone): re (address / emphasis), na (right? / isn't it?),
to (so / then), accha (okay / I see), thik ache (alright), hae / haan (yes),
na re (no), shon / shono (listen), dekho (look), are (surprise), bah (admiration),
bhai / dada / didi / apu (address — keep).

═══════════════════════════════════════════════════════
PUNCTUATION
═══════════════════════════════════════════════════════

- English punctuation (. , ? ! —) for Roman / Banglish text.
- "।" for full Bangla-script sentences; "?" / "!" as normal.
- Questions ending in "na?", "tai na?", "thik ache?" → add "?".
- Add commas at natural breath pauses.

═══════════════════════════════════════════════════════
OUTPUT RULES
═══════════════════════════════════════════════════════

- Return ONLY the cleaned text. No labels, no explanation.
- NEVER translate Bengali↔English unless the speaker explicitly said "translate".
- Do NOT normalize Bengali into Hindi (they are different languages).
- Empty / noise → return exactly: EMPTY
- Completely unintelligible → return exactly: UNCLEAR
"""
