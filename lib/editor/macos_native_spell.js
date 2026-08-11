#!/usr/bin/osascript -l JavaScript
// Part of MCU 8051 IDE macOS port
//
// Bridge between the IDE's spell checker interface and the native macOS
// spell checking service (NSSpellChecker -- the same engine and system
// dictionaries used by TextEdit, Safari, etc.).
//
// Speaks a minimal subset of the ispell/hunspell "-a" pipe protocol that
// lib/editor/spell_check.tcl understands:
//   - on start-up, prints a "@(#) ..." banner line (readiness handshake)
//   - for every input line (one word per line), prints one result line:
//         "*"          the word is spelled correctly
//         "# word 0"   the word is misspelled
//     followed by an empty line
//
// Runs on every macOS system with no third-party dependencies (osascript
// and the JavaScript for Automation ObjC bridge ship with the OS).

ObjC.import('Foundation');
ObjC.import('AppKit');

function run(argv) {
	var stdin  = $.NSFileHandle.fileHandleWithStandardInput;
	var stdout = $.NSFileHandle.fileHandleWithStandardOutput;

	function writeLine(s) {
		stdout.writeData(
			$.NSString.alloc.initWithUTF8String(s + '\n')
				.dataUsingEncoding($.NSUTF8StringEncoding));
	}

	var checker = $.NSSpellChecker.sharedSpellChecker;
	// Follow the user's system-wide spelling language configuration,
	// including "Automatic by Language"
	checker.automaticallyIdentifiesLanguages = true;

	function checkWord(word) {
		if (word.length === 0) {
			writeLine('');
			return;
		}
		var range = checker.checkSpellingOfStringStartingAt($(word), 0);
		if (range.location == $.NSNotFound) {
			writeLine('*');
		} else {
			writeLine('# ' + word + ' 0');
		}
		writeLine('');
	}

	// Ispell-style banner == readiness handshake for the IDE
	writeLine('@(#) International Ispell Version 3.1.20 (but really macOS NSSpellChecker)');

	// Read stdin line by line until EOF
	var buffer = '';
	while (true) {
		var data = stdin.availableData;	// blocks until data or EOF
		if (data.length == 0) {
			break;			// EOF -- the IDE closed the pipe
		}
		var chunk = $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding);
		if (chunk.isNil()) {
			continue;		// undecodable chunk -- skip
		}
		buffer += chunk.js;
		var idx;
		while ((idx = buffer.indexOf('\n')) >= 0) {
			var line = buffer.slice(0, idx);
			buffer = buffer.slice(idx + 1);
			checkWord(line.replace(/\r$/, ''));
		}
	}
}
