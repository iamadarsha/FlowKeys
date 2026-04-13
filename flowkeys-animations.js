/* ============================================================
   FlowKeys — Animation Controller
   Standalone JS: add before </body> in every HTML mockup
   DO NOT modify colors, layout, spacing, fonts, or structure
   ============================================================ */

(function () {
  'use strict';

  /* ----------------------------------------------------------
     UTILITY
     ---------------------------------------------------------- */

  /** Add/remove an animation class and clean up after it fires. */
  function animClass(el, cls, onDone) {
    if (!el) return;
    el.classList.remove(cls);
    void el.offsetWidth; // force reflow
    el.classList.add(cls);
    function cleanup() {
      el.classList.remove(cls);
      el.removeEventListener('animationend', cleanup);
      if (onDone) onDone();
    }
    el.addEventListener('animationend', cleanup);
  }

  /** easeOutCubic RAF counter for stat numbers. */
  function bindCounter(el) {
    const target  = parseFloat(el.dataset.count)  || 0;
    const suffix  = el.dataset.suffix              || '';
    const dur     = 1200; // ms
    let started   = false;

    const observer = new IntersectionObserver(entries => {
      if (entries[0].isIntersecting && !started) {
        started = true;
        observer.disconnect();
        const start = performance.now();
        function tick(now) {
          const t        = Math.min((now - start) / dur, 1);
          const progress = 1 - Math.pow(1 - t, 3); // easeOutCubic
          el.textContent = Math.round(target * progress) + suffix;
          if (t < 1) requestAnimationFrame(tick);
        }
        requestAnimationFrame(tick);
      }
    });
    observer.observe(el);
  }

  /* ----------------------------------------------------------
     PRIORITY 1 — MENU BAR POPOVER
     ---------------------------------------------------------- */

  function initMenuBarPopover() {
    // Popover open/close
    document.querySelectorAll('[data-open-popover]').forEach(trigger => {
      trigger.addEventListener('click', () => {
        const id     = trigger.dataset.openPopover;
        const popover = document.getElementById(id) ||
                        document.querySelector('[data-popover]');
        if (!popover) return;
        popover.style.display = 'block';
        popover.style.pointerEvents = 'auto';
        animClass(popover, 'fk-popover-enter');
      });
    });

    document.querySelectorAll('[data-close-popover]').forEach(btn => {
      btn.addEventListener('click', () => {
        const popover = btn.closest('[data-popover]') ||
                        document.querySelector('[data-popover]');
        if (!popover) return;
        animClass(popover, 'fk-popover-exit', () => {
          popover.style.display = 'none';
        });
      });
    });

    // Tone grid — bounce + active class
    document.querySelectorAll('[data-tone]').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('[data-tone]').forEach(b => b.classList.remove('tone-active'));
        btn.classList.add('tone-active');
        animClass(btn, 'fk-tone-select');
      });
    });

    // Language switcher — slide indicator
    const langTrack = document.querySelector('[data-lang-track]');
    if (langTrack) {
      const indicator = langTrack.querySelector('.fk-lang-indicator');
      langTrack.querySelectorAll('[data-lang]').forEach((btn, i) => {
        btn.addEventListener('click', () => {
          langTrack.querySelectorAll('[data-lang]').forEach(b => b.classList.remove('lang-active'));
          btn.classList.add('lang-active');
          if (indicator) {
            indicator.style.left  = btn.offsetLeft  + 'px';
            indicator.style.width = btn.offsetWidth + 'px';
          }
        });
      });
    }

    // Waveform logo idle animation
    document.querySelectorAll('[data-waveform]').forEach(wf => {
      wf.classList.add('fk-waveform-idle');
    });
  }

  /* ----------------------------------------------------------
     PRIORITY 2 — RECORDING PILL  (5-state machine)
     States: idle | recording | processing | done | error
     ---------------------------------------------------------- */

  const PILL_STATES = ['idle', 'recording', 'processing', 'done', 'error'];

  function setPillState(state) {
    if (!PILL_STATES.includes(state)) return;
    const pill = document.querySelector('[data-pill]');
    if (!pill) return;

    // Remove all state classes
    PILL_STATES.forEach(s => pill.classList.remove('pill-' + s));
    pill.classList.add('pill-' + state);

    const wf = pill.querySelector('[data-waveform]');

    if (wf) {
      wf.classList.remove('fk-waveform-active', 'fk-waveform-idle', 'fk-waveform-flat');
    }

    switch (state) {
      case 'idle':
        if (wf) wf.classList.add('fk-waveform-idle');
        break;

      case 'recording':
        if (wf) wf.classList.add('fk-waveform-active');
        pill.classList.add('fk-panel-enter');
        break;

      case 'processing':
        if (wf) wf.classList.add('fk-waveform-flat');
        break;

      case 'done': {
        const check = pill.querySelector('[data-done-icon]');
        const ring  = pill.querySelector('[data-done-ring]');
        if (check) animClass(check, 'fk-check-bounce');
        if (ring)  animClass(ring,  'fk-done-ring');
        // Auto-dismiss after 1.6s
        setTimeout(() => animClass(pill, 'fk-pill-dismiss', () => {
          setPillState('idle');
        }), 1600);
        break;
      }

      case 'error':
        animClass(pill, 'fk-error-wobble');
        break;
    }
  }

  function initRecordingPill() {
    // Wire demo buttons if present in mockup
    document.querySelectorAll('[data-set-pill-state]').forEach(btn => {
      btn.addEventListener('click', () => setPillState(btn.dataset.setPillState));
    });

    // Retry button on error state
    document.querySelectorAll('[data-pill-retry]').forEach(btn => {
      btn.addEventListener('click', () => setPillState('idle'));
    });
  }

  /* ----------------------------------------------------------
     PRIORITY 3 — SIDEBAR NAV
     ---------------------------------------------------------- */

  function initSidebarNav() {
    const nav = document.querySelector('[data-sidebar-nav]');
    if (!nav) return;

    const indicator = nav.querySelector('.fk-nav-indicator');
    const items     = nav.querySelectorAll('[data-nav-item]');

    function setActive(item) {
      items.forEach(i => i.classList.remove('nav-active'));
      item.classList.add('nav-active');
      if (indicator) {
        indicator.style.top    = item.offsetTop    + 'px';
        indicator.style.height = item.offsetHeight + 'px';
        indicator.style.opacity = '1';
      }
    }

    items.forEach(item => {
      item.addEventListener('click', () => setActive(item));
    });

    // Activate first item on load
    if (items[0]) setActive(items[0]);
  }

  /* ----------------------------------------------------------
     PRIORITY 4 — SETTINGS CARDS  (stagger on mount)
     ---------------------------------------------------------- */

  function initSettingsCards() {
    document.querySelectorAll('[data-settings-cards]').forEach(container => {
      const cards = container.querySelectorAll('[data-settings-card]');
      cards.forEach((card, i) => {
        card.style.animationDelay = (i * 50) + 'ms';
        card.classList.add('fk-card-enter');
      });
    });

    // Toggle switches
    initToggleSwitches();
  }

  /* ----------------------------------------------------------
     PRIORITY 5 — TOGGLE SWITCHES
     ---------------------------------------------------------- */

  function initToggleSwitches() {
    document.querySelectorAll('[data-toggle]').forEach(toggle => {
      const thumb = toggle.querySelector('.fk-toggle-thumb');
      toggle.classList.add('fk-toggle');

      toggle.addEventListener('click', () => {
        toggle.classList.toggle('toggle-on');
        // Pop the thumb
        if (thumb) animClass(thumb, 'fk-badge-pop');
      });
    });
  }

  /* ----------------------------------------------------------
     PRIORITY 6 — STAT COUNTERS
     ---------------------------------------------------------- */

  function initCounters() {
    document.querySelectorAll('[data-count]').forEach(bindCounter);
  }

  /* ----------------------------------------------------------
     PRIORITY 7 — ONBOARDING STEPS
     ---------------------------------------------------------- */

  function initOnboarding() {
    const container = document.querySelector('[data-onboarding]');
    if (!container) return;

    const steps       = Array.from(container.querySelectorAll('[data-step]'));
    const dots        = container.querySelectorAll('.fk-progress-dot');
    let currentIndex  = 0;

    function goToStep(nextIndex, direction) {
      if (nextIndex < 0 || nextIndex >= steps.length) return;
      const current = steps[currentIndex];
      const next    = steps[nextIndex];
      const forward = nextIndex > currentIndex;

      // Exit current
      const exitCls   = forward ? 'fk-step-exit-left'  : 'fk-step-exit-right';
      const enterCls  = forward ? 'fk-step-enter-right' : 'fk-step-enter-left';

      current.classList.add(exitCls);
      current.addEventListener('animationend', () => {
        current.classList.remove(exitCls);
        current.style.display = 'none';
      }, { once: true });

      // Enter next
      next.style.display = 'block';
      animClass(next, enterCls);

      // Update progress dots
      dots.forEach((dot, i) => {
        dot.classList.remove('dot-active', 'dot-default');
        dot.classList.add(i === nextIndex ? 'dot-active' : 'dot-default');
      });

      currentIndex = nextIndex;
    }

    // Next / back buttons
    container.querySelectorAll('[data-step-next]').forEach(btn => {
      btn.addEventListener('click', () => goToStep(currentIndex + 1));
    });
    container.querySelectorAll('[data-step-back]').forEach(btn => {
      btn.addEventListener('click', () => goToStep(currentIndex - 1));
    });

    // Provider card selection
    container.querySelectorAll('[data-provider-card]').forEach(card => {
      card.classList.add('fk-provider-card');
      card.addEventListener('click', () => {
        container.querySelectorAll('[data-provider-card]').forEach(c => c.classList.remove('card-selected'));
        card.classList.add('card-selected');
        animClass(card, 'fk-badge-pop');
      });
    });

    // API key input validation (simulated)
    container.querySelectorAll('[data-api-input]').forEach(input => {
      input.classList.add('fk-input');
      let timer;
      input.addEventListener('input', () => {
        input.classList.remove('fk-validating');
        clearTimeout(timer);
        if (input.value.length > 4) {
          timer = setTimeout(() => {
            void input.offsetWidth;
            input.classList.add('fk-validating');
            setTimeout(() => input.classList.remove('fk-validating'), 700);
          }, 400);
        }
      });
    });

    // Init first step
    steps.forEach((s, i) => {
      s.style.display = i === 0 ? 'block' : 'none';
    });
    if (dots[0]) {
      dots[0].classList.add('dot-active');
      dots.forEach((d, i) => { if (i > 0) d.classList.add('dot-default'); });
    }
  }

  /* ----------------------------------------------------------
     PRIORITY 8 — SMART MODES  (add rule, delete, dropdown)
     ---------------------------------------------------------- */

  function _bindRuleRow(row) {
    const del = row.querySelector('[data-delete-row]');
    if (del) {
      del.addEventListener('click', () => {
        animClass(row, 'fk-row-remove', () => row.remove());
      });
    }
  }

  function initSmartModes() {
    // Existing rows
    document.querySelectorAll('[data-rule-row]').forEach(_bindRuleRow);

    // Add new rule
    document.querySelectorAll('[data-add-rule]').forEach(btn => {
      btn.addEventListener('click', () => {
        const list    = btn.closest('[data-rules-list]') ||
                        btn.parentElement.querySelector('[data-rules-list]') ||
                        document.querySelector('[data-rules-list]');
        if (!list) return;

        const template = list.querySelector('[data-rule-row]');
        if (!template) return;

        const clone = template.cloneNode(true);
        clone.querySelectorAll('input, textarea').forEach(inp => inp.value = '');
        list.appendChild(clone);
        animClass(clone, 'fk-row-insert');
        _bindRuleRow(clone);
      });
    });

    // Dropdowns (mode selector etc.)
    document.querySelectorAll('[data-dropdown-trigger]').forEach(trigger => {
      trigger.addEventListener('click', () => {
        const id   = trigger.dataset.dropdownTrigger;
        const menu = document.getElementById(id) ||
                     trigger.nextElementSibling;
        if (!menu) return;
        const isOpen = menu.classList.contains('fk-dropdown-open');
        // Close all open dropdowns
        document.querySelectorAll('.fk-dropdown-open').forEach(m => {
          m.classList.remove('fk-dropdown-open');
          m.style.display = 'none';
        });
        if (!isOpen) {
          menu.style.display = 'block';
          void menu.offsetWidth;
          menu.classList.add('fk-dropdown-open');
        }
      });
    });

    // Close dropdowns when clicking outside
    document.addEventListener('click', e => {
      if (!e.target.closest('[data-dropdown-trigger]') &&
          !e.target.closest('[data-dropdown-menu]')) {
        document.querySelectorAll('[data-dropdown-menu]').forEach(m => {
          m.classList.remove('fk-dropdown-open');
          m.style.display = 'none';
        });
      }
    });

    // Dashed drop zone breathe
    document.querySelectorAll('[data-dashed-zone]').forEach(el => {
      el.classList.add('fk-dropzone-active');
    });
  }

  /* ----------------------------------------------------------
     PRIORITY 9 — FILE TRANSCRIPTION
     ---------------------------------------------------------- */

  /**
   * Transition between file upload UI states:
   * 'upload' → 'processing' → 'result' → 'upload'
   */
  function _transitionFileCard(panel, toState) {
    const views = panel.querySelectorAll('[data-file-state]');
    views.forEach(v => {
      if (v.dataset.fileState === toState) {
        v.style.display = 'block';
        animClass(v, 'fk-panel-enter');
      } else {
        v.style.display = 'none';
      }
    });
  }

  /**
   * Public: update file transcription progress (0–100).
   * Call from JS whenever upload / processing progress changes.
   * @param {number} value — 0 to 100
   */
  function fkUpdateProgress(value) {
    document.querySelectorAll('[data-progress-fill]').forEach(bar => {
      bar.style.width = Math.min(100, Math.max(0, value)) + '%';
    });
  }

  function initFileTranscription() {
    const panel = document.querySelector('[data-file-transcription]');
    if (!panel) return;

    // Panel rise on mount
    animClass(panel, 'fk-panel-enter');

    // State buttons (for demo)
    panel.querySelectorAll('[data-set-file-state]').forEach(btn => {
      btn.addEventListener('click', () => _transitionFileCard(panel, btn.dataset.setFileState));
    });

    // Drop zone
    const dropzone = panel.querySelector('[data-dropzone]');
    if (dropzone) {
      dropzone.classList.add('fk-dropzone-active');

      dropzone.addEventListener('dragover', e => {
        e.preventDefault();
        dropzone.classList.add('fk-dropzone-active');
      });
      dropzone.addEventListener('dragleave', () => {
        dropzone.classList.remove('fk-dropzone-active');
      });
      dropzone.addEventListener('drop', e => {
        e.preventDefault();
        dropzone.classList.remove('fk-dropzone-active');
        _transitionFileCard(panel, 'processing');
        // Simulate progress
        let progress = 0;
        const iv = setInterval(() => {
          progress += 8;
          fkUpdateProgress(progress);
          if (progress >= 100) {
            clearInterval(iv);
            setTimeout(() => _transitionFileCard(panel, 'result'), 400);
          }
        }, 150);
      });
    }

    // File input open
    const fileInput = panel.querySelector('[data-file-input]');
    panel.querySelectorAll('[data-open-file]').forEach(btn => {
      btn.addEventListener('click', () => fileInput && fileInput.click());
    });

    // Clear / reset
    panel.querySelectorAll('[data-file-reset]').forEach(btn => {
      btn.addEventListener('click', () => {
        fkUpdateProgress(0);
        _transitionFileCard(panel, 'upload');
      });
    });
  }

  /* ----------------------------------------------------------
     PRIORITY 10 — PIPELINE DEBUG
     ---------------------------------------------------------- */

  function initPipelineDebug() {
    const panel = document.querySelector('[data-pipeline-debug]');
    if (!panel) return;

    // Panel entrance
    animClass(panel, 'fk-panel-enter');

    // Accordion sections
    panel.querySelectorAll('[data-accordion-trigger]').forEach(trigger => {
      const id      = trigger.dataset.accordionTrigger;
      const content = document.getElementById(id) ||
                      trigger.nextElementSibling;
      if (!content) return;
      content.classList.add('fk-accordion');

      trigger.addEventListener('click', () => {
        const isOpen = content.classList.contains('accordion-open');
        // Close all in this panel
        panel.querySelectorAll('.fk-accordion').forEach(a => a.classList.remove('accordion-open'));
        panel.querySelectorAll('[data-accordion-trigger]').forEach(t => t.classList.remove('trigger-open'));

        if (!isOpen) {
          content.classList.add('accordion-open');
          trigger.classList.add('trigger-open');

          // Stagger grid children on open
          const gridItems = content.querySelectorAll('[data-debug-card]');
          gridItems.forEach((item, i) => {
            item.style.animationDelay = (i * 40) + 'ms';
            animClass(item, 'fk-card-enter');
          });
        }
      });
    });

    // Status badge pop on new data
    panel.querySelectorAll('[data-status-badge]').forEach(badge => {
      // MutationObserver watches for text changes
      const obs = new MutationObserver(() => {
        animClass(badge, 'fk-badge-pop');
      });
      obs.observe(badge, { childList: true, subtree: true, characterData: true });
    });
  }

  /* ----------------------------------------------------------
     SHORTCUT RECORDER
     ---------------------------------------------------------- */

  function initShortcutRecorder() {
    const panel = document.querySelector('[data-shortcut-recorder]');
    if (!panel) return;

    animClass(panel, 'fk-panel-enter');

    // Capture mode — pulsing ring on the capture target
    panel.querySelectorAll('[data-start-capture]').forEach(btn => {
      btn.addEventListener('click', () => {
        const target = panel.querySelector('[data-capture-target]') || btn;
        target.classList.add('fk-capture-pulse');
        target.dataset.capturing = 'true';
        btn.textContent = 'Recording…';
      });
    });

    // Confirm capture
    panel.querySelectorAll('[data-confirm-capture]').forEach(btn => {
      btn.addEventListener('click', () => {
        const target = panel.querySelector('[data-capture-target]');
        if (target) target.classList.remove('fk-capture-pulse');

        // Flash confirm state
        btn.classList.add('fk-shortcut-confirm');
        animClass(btn, 'fk-check-bounce');
        setTimeout(() => btn.classList.remove('fk-shortcut-confirm'), 400);

        // Crossfade label
        const label = panel.querySelector('[data-shortcut-label]');
        if (label) {
          label.style.opacity = '0';
          setTimeout(() => {
            const keyEl = panel.querySelector('[data-captured-key]');
            if (keyEl) label.textContent = keyEl.textContent || label.textContent;
            label.style.transition = 'opacity 200ms';
            label.style.opacity = '1';
          }, 150);
        }
      });
    });

    // Cancel
    panel.querySelectorAll('[data-cancel-capture]').forEach(btn => {
      btn.addEventListener('click', () => {
        const target = panel.querySelector('[data-capture-target]');
        if (target) {
          target.classList.remove('fk-capture-pulse');
          delete target.dataset.capturing;
        }
        const startBtn = panel.querySelector('[data-start-capture]');
        if (startBtn) startBtn.textContent = 'Record…';
      });
    });

    // Close panel
    panel.querySelectorAll('[data-close-panel]').forEach(btn => {
      btn.addEventListener('click', () => {
        animClass(panel, 'fk-panel-exit', () => {
          panel.style.display = 'none';
        });
      });
    });
  }

  /* ----------------------------------------------------------
     RUN LOG
     ---------------------------------------------------------- */

  /**
   * Public: append a new log line to the run log.
   * @param {string} text
   * @param {string} [level] — 'info' | 'warn' | 'error'
   */
  function fkAppendLogLine(text, level) {
    const list = document.querySelector('[data-log-list]');
    if (!list) return;

    const line = document.createElement('div');
    line.classList.add('fk-log-line-appear');
    if (level) line.dataset.logLevel = level;
    line.textContent = text;
    list.appendChild(line);

    // Scroll to bottom
    const scroller = list.closest('[data-log-scroller]') || list.parentElement;
    if (scroller) scroller.scrollTop = scroller.scrollHeight;
  }

  function initRunLog() {
    const panel = document.querySelector('[data-run-log]');
    if (!panel) return;

    animClass(panel, 'fk-panel-enter');

    // Staggered card entrance
    panel.querySelectorAll('[data-log-card]').forEach((card, i) => {
      card.style.animationDelay = (i * 60) + 'ms';
      card.classList.add('fk-card-enter');
    });

    // Stat counters inside the panel
    panel.querySelectorAll('[data-count]').forEach(bindCounter);

    // Filter pills
    const pills = panel.querySelectorAll('[data-filter-pill]');
    pills.forEach(pill => {
      pill.classList.add('fk-filter-pill');
      pill.addEventListener('click', () => {
        pills.forEach(p => p.classList.remove('pill-active'));
        pill.classList.add('pill-active');
        animClass(pill, 'fk-badge-pop');

        // Filter rows
        const filter = pill.dataset.filterPill;
        panel.querySelectorAll('[data-log-row]').forEach(row => {
          const show = filter === 'all' || row.dataset.logRow === filter;
          if (show) {
            row.style.display = '';
            animClass(row, 'fk-log-line-appear');
          } else {
            row.style.display = 'none';
          }
        });
      });
    });

    // Row accordion expand
    panel.querySelectorAll('[data-log-row-trigger]').forEach(trigger => {
      const id      = trigger.dataset.logRowTrigger;
      const content = document.getElementById(id) ||
                      trigger.closest('[data-log-row]')?.querySelector('[data-log-row-content]');
      if (!content) return;
      content.classList.add('fk-accordion');

      trigger.addEventListener('click', () => {
        const isOpen = content.classList.contains('accordion-open');
        content.classList.toggle('accordion-open', !isOpen);
      });
    });

    // Row delete
    panel.querySelectorAll('[data-delete-log-row]').forEach(btn => {
      btn.addEventListener('click', () => {
        const row = btn.closest('[data-log-row]');
        if (row) animClass(row, 'fk-row-remove', () => row.remove());
      });
    });
  }

  /* ----------------------------------------------------------
     AMBIENT ANIMATIONS
     No-op: handled purely by CSS classes added in markup.
     (.fk-orb-drift, .fk-logo-breathing, .fk-badge-recording)
     ---------------------------------------------------------- */

  function initAmbientAnimations() {
    // Orb drift — auto-applied via CSS class; nothing to wire.
    // Badge recording dot — toggled by setRecordingActive().
  }

  /* ----------------------------------------------------------
     RECORDING ACTIVE STATE  (logo breathe + badge pulse)
     ---------------------------------------------------------- */

  function setRecordingActive(isActive) {
    const logo  = document.querySelector('[data-logo]');
    const badge = document.querySelector('[data-recording-badge]');
    const navIcon = document.querySelector('[data-nav-record-icon]');

    if (logo)    logo.classList.toggle('fk-logo-breathing', !!isActive);
    if (badge)   badge.classList.toggle('fk-badge-recording', !!isActive);
    if (navIcon) navIcon.classList.toggle('fk-logo-breathing', !!isActive);

    // Also update pill state
    setPillState(isActive ? 'recording' : 'idle');
  }

  /* ----------------------------------------------------------
     INIT — wire everything on DOMContentLoaded
     ---------------------------------------------------------- */

  function init() {
    initMenuBarPopover();
    initRecordingPill();
    initSidebarNav();
    initSettingsCards();
    initToggleSwitches();
    initCounters();
    initOnboarding();
    initSmartModes();
    initFileTranscription();
    initPipelineDebug();
    initShortcutRecorder();
    initRunLog();
    initAmbientAnimations();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  /* ----------------------------------------------------------
     PUBLIC API
     ---------------------------------------------------------- */
  window.fkSetPillState       = setPillState;
  window.fkSetRecordingActive = setRecordingActive;
  window.fkUpdateProgress     = fkUpdateProgress;
  window.fkAppendLogLine      = fkAppendLogLine;

})();
