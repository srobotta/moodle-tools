#!/usr/bin/env python3
"""
A small graphical front-end for import-cards.py.

It exposes every command-line option of import-cards.py as a form control,
builds the matching command line and runs the script, streaming its output
into a log area. Uses only the standard library (tkinter) so it runs on both
Windows and Linux without extra dependencies.

All user-facing text lives in the TRANSLATIONS table below. To add a language,
add a new entry to LANGUAGE_NAMES and a matching dictionary to TRANSLATIONS
with the same set of keys; nothing else in the code needs to change.
"""

import os
import queue
import subprocess
import sys
import threading
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

# import-cards.py is expected to sit next to this file.
SCRIPT_NAME = "import-cards.py"
SCRIPT_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), SCRIPT_NAME)

# Language code -> the name shown for it in the chooser (in its own language).
LANGUAGE_NAMES = {
    "de": "Deutsch",
    "en": "English",
    "fr": "Français",
}

# The default language used on start-up and as the fallback for any missing key.
DEFAULT_LANGUAGE = "en"

# All user-facing strings, keyed by language code then by string id.
# Strings with {placeholders} are filled in with str.format at display time.
TRANSLATIONS = {
    "en": {
        "window_title": "Import Cards",
        "language_label": "Language:",
        "h5p_label": "H5P file:",
        "ods_label": "ODS file:",
        "front_label": "Front column:",
        "front_hint": "(column letter for the questions, default A)",
        "back_label": "Back column:",
        "back_hint": "(column letter for the answers, default B)",
        "row_label": "Start row:",
        "row_hint": "(1-based row where the import starts)",
        "sheet_label": "Sheet name:",
        "sheet_hint": "(blank = first sheet)",
        "title_label": "Title:",
        "title_hint": "(blank = leave unchanged)",
        "browse_button": "Browse…",
        "import_button": "Import",
        "output_label": "Output:",
        "h5p_dialog_title": "Select the H5P file",
        "ods_dialog_title": "Select the ODS file",
        "filetype_h5p": "H5P files",
        "filetype_ods": "Open Document Spreadsheet",
        "filetype_all": "All files",
        "err_missing_title": "Missing input",
        "err_missing_h5p": "Please choose an H5P file.",
        "err_missing_ods": "Please choose an ODS file.",
        "err_invalid_title": "Invalid input",
        "err_invalid_row": "Start row must be a positive whole number.",
        "busy_title": "Busy",
        "busy_msg": "An import is already running.",
        "script_not_found_title": "Script not found",
        "script_not_found_msg": "Could not find {name} next to this program:\n{path}",
        "running": "Running: {cmd}\n\n",
        "done": "\nDone.\n",
        "failed": "\nFailed (exit code {code}).\n",
        "error": "\nError: {exc}\n",
    },
    "de": {
        "window_title": "Karten importieren",
        "language_label": "Sprache:",
        "h5p_label": "H5P-Datei:",
        "ods_label": "ODS-Datei:",
        "front_label": "Vorderseite (Spalte):",
        "front_hint": "(Spaltenbuchstabe für die Fragen, Standard A)",
        "back_label": "Rückseite (Spalte):",
        "back_hint": "(Spaltenbuchstabe für die Antworten, Standard B)",
        "row_label": "Startzeile:",
        "row_hint": "(1-basierte Zeile, bei der der Import beginnt)",
        "sheet_label": "Tabellenblatt:",
        "sheet_hint": "(leer = erstes Blatt)",
        "title_label": "Titel:",
        "title_hint": "(leer = unverändert lassen)",
        "browse_button": "Durchsuchen…",
        "import_button": "Importieren",
        "output_label": "Ausgabe:",
        "h5p_dialog_title": "H5P-Datei auswählen",
        "ods_dialog_title": "ODS-Datei auswählen",
        "filetype_h5p": "H5P-Dateien",
        "filetype_ods": "OpenDocument-Tabelle",
        "filetype_all": "Alle Dateien",
        "err_missing_title": "Fehlende Eingabe",
        "err_missing_h5p": "Bitte eine H5P-Datei auswählen.",
        "err_missing_ods": "Bitte eine ODS-Datei auswählen.",
        "err_invalid_title": "Ungültige Eingabe",
        "err_invalid_row": "Die Startzeile muss eine positive ganze Zahl sein.",
        "busy_title": "Beschäftigt",
        "busy_msg": "Ein Import läuft bereits.",
        "script_not_found_title": "Skript nicht gefunden",
        "script_not_found_msg": "{name} wurde nicht neben diesem Programm gefunden:\n{path}",
        "running": "Wird ausgeführt: {cmd}\n\n",
        "done": "\nFertig.\n",
        "failed": "\nFehlgeschlagen (Exit-Code {code}).\n",
        "error": "\nFehler: {exc}\n",
    },
    "fr": {
        "window_title": "Importer les cartes",
        "language_label": "Langue :",
        "h5p_label": "Fichier H5P :",
        "ods_label": "Fichier ODS :",
        "front_label": "Colonne recto :",
        "front_hint": "(lettre de colonne pour les questions, par défaut A)",
        "back_label": "Colonne verso :",
        "back_hint": "(lettre de colonne pour les réponses, par défaut B)",
        "row_label": "Ligne de début :",
        "row_hint": "(ligne, à partir de 1, où commence l'import)",
        "sheet_label": "Nom de la feuille :",
        "sheet_hint": "(vide = première feuille)",
        "title_label": "Titre :",
        "title_hint": "(vide = laisser inchangé)",
        "browse_button": "Parcourir…",
        "import_button": "Importer",
        "output_label": "Sortie :",
        "h5p_dialog_title": "Sélectionner le fichier H5P",
        "ods_dialog_title": "Sélectionner le fichier ODS",
        "filetype_h5p": "Fichiers H5P",
        "filetype_ods": "Feuille de calcul OpenDocument",
        "filetype_all": "Tous les fichiers",
        "err_missing_title": "Saisie manquante",
        "err_missing_h5p": "Veuillez choisir un fichier H5P.",
        "err_missing_ods": "Veuillez choisir un fichier ODS.",
        "err_invalid_title": "Saisie invalide",
        "err_invalid_row": "La ligne de début doit être un entier positif.",
        "busy_title": "Occupé",
        "busy_msg": "Un import est déjà en cours.",
        "script_not_found_title": "Script introuvable",
        "script_not_found_msg": "Impossible de trouver {name} à côté de ce programme :\n{path}",
        "running": "Exécution : {cmd}\n\n",
        "done": "\nTerminé.\n",
        "failed": "\nÉchec (code de sortie {code}).\n",
        "error": "\nErreur : {exc}\n",
    },
}


class ImportCardsGUI:
    def __init__(self, root):
        self.root = root
        self.lang = DEFAULT_LANGUAGE

        # Queue used to pass output lines from the worker thread to the UI.
        self.output_queue = queue.Queue()
        self.process = None

        # Widgets whose text depends on the language are collected here so that
        # retranslate() can update them all when the language changes. Maps a
        # widget to the translation key for its text.
        self._translatable = {}

        self._build_widgets()
        self.retranslate()
        self.root.after(100, self._drain_output)

    def tr(self, key, **kwargs):
        """Look up a string for the current language, falling back to the
        default language and finally to the key itself. Fills in placeholders."""
        text = TRANSLATIONS.get(self.lang, {}).get(key)
        if text is None:
            text = TRANSLATIONS[DEFAULT_LANGUAGE].get(key, key)
        if kwargs:
            text = text.format(**kwargs)
        return text

    def _register(self, widget, key):
        """Remember a widget so its text is refreshed on a language change."""
        self._translatable[widget] = key
        return widget

    def _build_widgets(self):
        pad = {"padx": 6, "pady": 4}
        frame = ttk.Frame(self.root, padding=10)
        frame.grid(row=0, column=0, sticky="nsew")
        self.root.rowconfigure(0, weight=1)
        self.root.columnconfigure(0, weight=1)
        frame.columnconfigure(1, weight=1)
        self.root.minsize(560, 480)

        row = 0

        # --- language chooser ---
        self._register(
            ttk.Label(frame), "language_label"
        ).grid(row=row, column=0, sticky="w", **pad)
        # Map the shown name back to its language code.
        self._name_to_code = {name: code for code, name in LANGUAGE_NAMES.items()}
        self.lang_combo = ttk.Combobox(
            frame,
            state="readonly",
            values=list(LANGUAGE_NAMES.values()),
            width=16,
        )
        self.lang_combo.set(LANGUAGE_NAMES[self.lang])
        self.lang_combo.grid(row=row, column=1, sticky="w", **pad)
        self.lang_combo.bind("<<ComboboxSelected>>", self._on_language_change)
        row += 1

        # --- h5p file (required) ---
        self._register(ttk.Label(frame), "h5p_label").grid(
            row=row, column=0, sticky="w", **pad
        )
        self.h5p_var = tk.StringVar()
        ttk.Entry(frame, textvariable=self.h5p_var).grid(
            row=row, column=1, sticky="ew", **pad
        )
        self._register(
            ttk.Button(frame, command=self._pick_h5p), "browse_button"
        ).grid(row=row, column=2, **pad)
        row += 1

        # --- ods file (required) ---
        self._register(ttk.Label(frame), "ods_label").grid(
            row=row, column=0, sticky="w", **pad
        )
        self.ods_var = tk.StringVar()
        ttk.Entry(frame, textvariable=self.ods_var).grid(
            row=row, column=1, sticky="ew", **pad
        )
        self._register(
            ttk.Button(frame, command=self._pick_ods), "browse_button"
        ).grid(row=row, column=2, **pad)
        row += 1

        # --- front column (--front, default A) ---
        self._register(ttk.Label(frame), "front_label").grid(
            row=row, column=0, sticky="w", **pad
        )
        self.front_var = tk.StringVar(value="A")
        ttk.Entry(frame, textvariable=self.front_var, width=10).grid(
            row=row, column=1, sticky="w", **pad
        )
        self._register(ttk.Label(frame), "front_hint").grid(
            row=row, column=2, sticky="w", **pad
        )
        row += 1

        # --- back column (--back, default B) ---
        self._register(ttk.Label(frame), "back_label").grid(
            row=row, column=0, sticky="w", **pad
        )
        self.back_var = tk.StringVar(value="B")
        ttk.Entry(frame, textvariable=self.back_var, width=10).grid(
            row=row, column=1, sticky="w", **pad
        )
        self._register(ttk.Label(frame), "back_hint").grid(
            row=row, column=2, sticky="w", **pad
        )
        row += 1

        # --- start row (--row, default 1) ---
        self._register(ttk.Label(frame), "row_label").grid(
            row=row, column=0, sticky="w", **pad
        )
        self.row_var = tk.StringVar(value="1")
        ttk.Spinbox(
            frame, from_=1, to=1000000, textvariable=self.row_var, width=8
        ).grid(row=row, column=1, sticky="w", **pad)
        self._register(ttk.Label(frame), "row_hint").grid(
            row=row, column=2, sticky="w", **pad
        )
        row += 1

        # --- sheet (--sheet, optional) ---
        self._register(ttk.Label(frame), "sheet_label").grid(
            row=row, column=0, sticky="w", **pad
        )
        self.sheet_var = tk.StringVar()
        ttk.Entry(frame, textvariable=self.sheet_var).grid(
            row=row, column=1, sticky="ew", **pad
        )
        self._register(ttk.Label(frame), "sheet_hint").grid(
            row=row, column=2, sticky="w", **pad
        )
        row += 1

        # --- title (--title, optional) ---
        self._register(ttk.Label(frame), "title_label").grid(
            row=row, column=0, sticky="w", **pad
        )
        self.title_var = tk.StringVar()
        ttk.Entry(frame, textvariable=self.title_var).grid(
            row=row, column=1, sticky="ew", **pad
        )
        self._register(ttk.Label(frame), "title_hint").grid(
            row=row, column=2, sticky="w", **pad
        )
        row += 1

        # --- run button ---
        self.run_button = self._register(
            ttk.Button(frame, command=self._run), "import_button"
        )
        self.run_button.grid(row=row, column=0, columnspan=3, pady=(10, 4))
        row += 1

        # --- output log ---
        self._register(ttk.Label(frame), "output_label").grid(
            row=row, column=0, sticky="w", **pad
        )
        row += 1
        log_frame = ttk.Frame(frame)
        log_frame.grid(row=row, column=0, columnspan=3, sticky="nsew", **pad)
        frame.rowconfigure(row, weight=1)
        log_frame.rowconfigure(0, weight=1)
        log_frame.columnconfigure(0, weight=1)

        self.log = tk.Text(log_frame, height=10, wrap="word", state="disabled")
        self.log.grid(row=0, column=0, sticky="nsew")
        scroll = ttk.Scrollbar(log_frame, command=self.log.yview)
        scroll.grid(row=0, column=1, sticky="ns")
        self.log.configure(yscrollcommand=scroll.set)

    def retranslate(self):
        """Refresh every language-dependent widget and the window title."""
        self.root.title(self.tr("window_title"))
        for widget, key in self._translatable.items():
            widget.configure(text=self.tr(key))

    def _on_language_change(self, _event=None):
        name = self.lang_combo.get()
        self.lang = self._name_to_code.get(name, DEFAULT_LANGUAGE)
        self.retranslate()

    def _pick_h5p(self):
        path = filedialog.askopenfilename(
            title=self.tr("h5p_dialog_title"),
            filetypes=[
                (self.tr("filetype_h5p"), "*.h5p"),
                (self.tr("filetype_all"), "*.*"),
            ],
        )
        if path:
            self.h5p_var.set(path)

    def _pick_ods(self):
        path = filedialog.askopenfilename(
            title=self.tr("ods_dialog_title"),
            filetypes=[
                (self.tr("filetype_ods"), "*.ods"),
                (self.tr("filetype_all"), "*.*"),
            ],
        )
        if path:
            self.ods_var.set(path)

    def _build_command(self):
        """Validate the inputs and return the argument list, or None on error."""
        h5p = self.h5p_var.get().strip()
        ods = self.ods_var.get().strip()
        if not h5p:
            messagebox.showerror(
                self.tr("err_missing_title"), self.tr("err_missing_h5p")
            )
            return None
        if not ods:
            messagebox.showerror(
                self.tr("err_missing_title"), self.tr("err_missing_ods")
            )
            return None

        row = self.row_var.get().strip() or "1"
        if not row.isdigit() or int(row) < 1:
            messagebox.showerror(
                self.tr("err_invalid_title"), self.tr("err_invalid_row")
            )
            return None

        cmd = [sys.executable, SCRIPT_PATH]

        front = self.front_var.get().strip()
        if front:
            cmd += ["--front", front]
        back = self.back_var.get().strip()
        if back:
            cmd += ["--back", back]
        cmd += ["--row", row]
        sheet = self.sheet_var.get().strip()
        if sheet:
            cmd += ["--sheet", sheet]
        title = self.title_var.get().strip()
        if title:
            cmd += ["--title", title]

        # Positional arguments come last.
        cmd += [h5p, ods]
        return cmd

    def _run(self):
        if self.process is not None:
            messagebox.showinfo(self.tr("busy_title"), self.tr("busy_msg"))
            return
        if not os.path.exists(SCRIPT_PATH):
            messagebox.showerror(
                self.tr("script_not_found_title"),
                self.tr(
                    "script_not_found_msg", name=SCRIPT_NAME, path=SCRIPT_PATH
                ),
            )
            return

        cmd = self._build_command()
        if cmd is None:
            return

        self._clear_log()
        self._append_log(self.tr("running", cmd=" ".join(cmd)))
        self.run_button.configure(state="disabled")

        thread = threading.Thread(target=self._worker, args=(cmd,), daemon=True)
        thread.start()

    def _worker(self, cmd):
        """Run the script in a subprocess and push its output into the queue."""
        try:
            self.process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                universal_newlines=True,
                bufsize=1,
            )
            for line in self.process.stdout:
                self.output_queue.put(line)
            self.process.stdout.close()
            code = self.process.wait()
            if code == 0:
                self.output_queue.put(self.tr("done"))
            else:
                self.output_queue.put(self.tr("failed", code=code))
        except Exception as exc:  # noqa: BLE001 - surface any launch error to the UI
            self.output_queue.put(self.tr("error", exc=exc))
        finally:
            self.process = None
            self.output_queue.put(None)  # sentinel: re-enable the button

    def _drain_output(self):
        """Poll the queue and move any pending output into the log widget."""
        try:
            while True:
                item = self.output_queue.get_nowait()
                if item is None:
                    self.run_button.configure(state="normal")
                else:
                    self._append_log(item)
        except queue.Empty:
            pass
        self.root.after(100, self._drain_output)

    def _append_log(self, text):
        self.log.configure(state="normal")
        self.log.insert("end", text)
        self.log.see("end")
        self.log.configure(state="disabled")

    def _clear_log(self):
        self.log.configure(state="normal")
        self.log.delete("1.0", "end")
        self.log.configure(state="disabled")


def main():
    root = tk.Tk()
    ImportCardsGUI(root)
    root.mainloop()


if __name__ == "__main__":
    main()
