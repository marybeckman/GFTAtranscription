#######################################################################
# Controls whether the @log_[...] procedures write to the InfoLines.
# debug_mode = 1
debug_mode = 0
continueTranscription = 1

include check_version.praat
include procs.praat
include startup_procs.praat
include transcription_startup.praat

# Numeric and string constants for the Word List Table.
wordListBasename$ = startup_GFTA_wordlist.table$
wordListWorldBet$ = startup_GFTA_wordlist.worldBet$
wordListTargetC1$ = startup_GFTA_wordlist.targetC1$
wordListTargetC2$ = startup_GFTA_wordlist.targetC2$
wordListTargetC3$ = startup_GFTA_wordlist.targetC3$
wordListprosPos1$ = startup_GFTA_wordlist.prosPos1$
wordListprosPos2$ = startup_GFTA_wordlist.prosPos2$
wordListprosPos3$ = startup_GFTA_wordlist.prosPos3$

# Column numbers from the segmented textgrid
segTextGridTrial = startup_segm_textgrid.trial
segTextGridContext = startup_segm_textgrid.context

# Count the trials of structure type
@count_GFTA_wordlist_structures(wordListBasename$)
nTrials = count_GFTA_wordlist_structures.nTrials

# Check whether the log and textgrid exist already
@gfta_trans_log("check", task$, experimental_ID$, initials$, transLogDirectory$, nTrials)
@gfta_trans_textgrid("check", task$, experimental_ID$, initials$, transDirectory$)

# Load or initialize the transcription log/textgrid iff
# the log/textgrid both exist already or both need to be created.
if gfta_trans_log.exists == gfta_trans_textgrid.exists
	@gfta_trans_log("load", task$, experimental_ID$, initials$, transLogDirectory$, nTrials)
	@gfta_trans_textgrid("load", task$, experimental_ID$, initials$, transDirectory$)
# Otherwise exit with an error message
else
	log_part$ = "Log " + gfta_trans_log.filename$
	grid_part$ = "TextGrid " + gfta_trans_textgrid.filename$
	if gfta_trans_log.exists
		msg$ = "Initialization error: " + log_part$ + "was found, but " + grid_part$ + " was not."
	else
		msg$ = "Initialization error: " + grid_part$ + "was found, but " + log_part$ + " was not."
	endif
	exitScript: msg$
endif

# Export values to global namespace
segmentBasename$ = startup_segm_textgrid.basename$
audioBasename$ = startup_load_audio.audio_sound$
transBasename$ = gfta_trans_textgrid.basename$
transLogBasename$ = gfta_trans_log.basename$

# These are column names
transLogTrials$ = gfta_trans_log.trials$
transLogTrialsTranscribed$ = gfta_trans_log.trials_transcribed$
transLogEndTime$ = gfta_trans_log.end$
transLogScore$ = gfta_trans_log.score$

###############################################################################
#                             Code for Transcription                                #
###############################################################################

# Open an Edit window with the segmentation textgrid, so that the transcriber can examine
# the larger segmentation context to recoup from infelicitous segmenting of false starts
# and the like. 
@selectTextGrid(segmentBasename$)
Edit

# Open a separate Editor window with the transcription textgrid object and audio file.
@selectTextGrid(transBasename$)
plusObject("Sound " + audioBasename$)
Edit
# Set the Spectrogram settings, etc., here.

#Count remaining trials

## does this log file increment for each session?  if so, this "1" should be changed to numRows
## in the log file.

@count_remaining_trials(transLogBasename$, 1)
n_trials = count_remaining_trials.n_trials
n_transcribed = count_remaining_trials.n_transcribed
n_remaining = count_remaining_trials.n_remaining

# If there are still trials to transcribe, ask the transcriber if she would like to transcribe them.
n_transcribed < n_trials
beginPause("Transcribe GFTA Trials")
	comment("There are 'n_remaining' trials to transcribe.")
	comment("Would you like to transcribe them?")
button = endPause("No", "Yes", 2, 1)

# If the user chooses no, skip the transcription loop and break out of this loop.
if button == 1
	continueTranscription = 0
else
	currentTrial = n_transcribed + 1
endif

@selectTable(segmentBasename$)
Extract rows where column (text): "tier", "is equal to", "Trial"
Rename: "TierTimes"

# Loop through the trials of the current type
while (currentTrial <= n_trials & continueTranscription)
	# Look up trial number in segmentation table. Compute trial midpoint from table.
	@selectTable("TierTimes")
	@get_xbounds_from_table("TierTimes", currentTrial)
	trialXMid = get_xbounds_from_table.xmid

	# Find bounds of the textgrid interval containing the trial midpoint
	@get_xbounds_in_textgrid_interval(segmentBasename$, segTextGridTrial, trialXMid)

	# Use the XMin and XMax of the current trial to extract that portion of the segmented 
	# TextGrid, preserving the times. The TextGrid Object that this operation creates will 
	# have the name:
	# ::ExperimentalTask::_::ExperimentalID::_::SegmentersInitials::segm_part
	@selectTextGrid(segmentBasename$)
	Extract part: get_xbounds_in_textgrid_interval.xmin, get_xbounds_in_textgrid_interval.xmax, "yes"

	# Convert the (extracted) TextGrid to a Table, which has the
	# same name as the TextGrid from which it was created.
	@selectTextGrid(segmentBasename$ + "_part")
	Down to Table: "no", 6, "yes", "no"
	@selectTextGrid(segmentBasename$ + "_part")
	Remove

	# Subset the 'segmentBasename$'_part Table to just the intervals on the Context Tier.
	@selectTable(segmentBasename$ + "_part")
	Extract rows where column (text): "tier", "is equal to", "Context"
	@selectTable(segmentBasename$ + "_part")
	Remove

	# Count the number of segmented intervals.
	@selectTable(segmentBasename$ + "_part_Context")
	numResponses = Get number of rows
	# If there is more than one segmented interval, ...
	if numResponses > 1
		# Zoom to the entire trial in the segmentation TextGrid object and 
		# invite the transcriber to select the interval to transcribe.
		editor TextGrid 'segmentBasename$'
			Zoom: get_xbounds_in_textgrid_interval.xmin, get_xbounds_in_textgrid_interval.xmax
		endeditor
		beginPause("Choose repetition number to transcribe")
			choice("Repetition number", numResponses)
				for repnum from 1 to 'numResponses'
					option("'repnum'")
				endfor
		button = endPause("Back", "Quit", "Choose repetition number", 3)
	else
		repetition_number = 1
	endif

	# Get the Context label of the chosen segmented interval of this trial and also then
	# mark it off in the transcription textgrid ready to transcribe or skip as a NonResponse.
	@selectTable(segmentBasename$ + "_part_Context")
	contextLabel$ = Get value: repetition_number, "text"

	# Determine the XMin and XMax of the segmented interval.
	@get_xbounds_from_table(segmentBasename$ + "_part_Context", repetition_number)
	segmentXMid = get_xbounds_from_table.xmid

	@get_xbounds_in_textgrid_interval(segmentBasename$, segTextGridContext, segmentXMid)
	segmentXMin = get_xbounds_in_textgrid_interval.xmin
	segmentXMax = get_xbounds_in_textgrid_interval.xmax

	# Add interval boundaries on each tier.
	@selectTextGrid(transBasename$)
	Insert boundary: gfta_trans_textgrid.prosodicPos, segmentXMin
	Insert boundary: gfta_trans_textgrid.prosodicPos, segmentXMax
	Insert boundary: gfta_trans_textgrid.phonemic, segmentXMin
	Insert boundary: gfta_trans_textgrid.phonemic, segmentXMax

	# Determine the target word and target segments. 
	@selectTable(wordListBasename$)
	targetWord$ = Get value: currentTrial, wordListWorldBet$
	targetC1$ = Get value: currentTrial, wordListTargetC1$
	targetC2$ = Get value: currentTrial, wordListTargetC2$
	targetC3$ = Get value: currentTrial, wordListTargetC3$
	prosPos1$ = Get value: currentTrial, wordListprosPos1$
	prosPos2$ = Get value: currentTrial, wordListprosPos2$
	prosPos3$ = Get value: currentTrial, wordListprosPos3$

	if targetC1$ != ""
		@TranscribeSegment(targetC1$, prosPos1$, currentTrial, 1, targetWord$)
	endif
	if targetC2$ != ""
		@TranscribeSegment(targetC2$, prosPos2$, currentTrial, 2, targetWord$)
	endif
	if targetC3$ != ""
		@TranscribeSegment(targetC3$, prosPos3$, currentTrial, 3, targetWord$)
	endif

##### This results in a very ungraceful way to quit midstream.  Figure out a better way.

	# Ask the user if they want to keep transcribing or quit.
	beginPause ("")
		comment ("Would you like to keep transcribing?")
	clicked = endPause("Ruin everything", "Quit for now", "Continue transcribing", 3, 1)

	# If the transcriber doesn't want to continue...
	if clicked = 2
		# If the transcriber decided to quit, then set the 'trial'
		# variable so that the script breaks out of the while-loop.
		continueTranscription = 0
	else
		# Remove the segmented interval's Table from the Praat Object list.
		@selectTable(segmentBasename$ + "_part_Context")
		Remove
	endif

	@selectTextGrid(transBasename$)
	Save as text file: gfta_trans_textgrid.filepath$

	@selectTable(transLogBasename$)
	@currentTime
	Set string value: 1, transLogEndTime$, currentTime.t$
	Set numeric value: 1, transLogTrialsTranscribed$, currentTrial
	Save as tab-separated file: gfta_trans_log.filepath$

	#increment trial number
	currentTrial = currentTrial + 1
endwhile

select all
Remove

procedure TranscribeSegment(.target$, .pros$, .currentTrial, .whichSegment, .word$)
	# Zoom to the segmented interval in the editor window.
	editor TextGrid 'transBasename$'
		Zoom: segmentXMin - 0.25, segmentXMax + 0.25
	endeditor

	beginPause ("Make a selection in the editor window")
#		comment ("Next sound to transcribe: '.target$'")
		comment ("Next sound to transcribe: '.target$' at '.pros$' in '.word$'")
		comment ("Please select the whole sound in the editor window")
	clicked = endPause ("Ruin everything", "Continue to transcribe this sound", 2, 1)

	editor TextGrid 'transBasename$'
		start_time = Get start of selection
		end_time = Get end of selection
		interval_mid = (start_time + ((end_time - start_time)/2))
	endeditor

	# Prompt the user to rate production.

	# Prompt for transcription code
	beginPause ("Rate the production of consonant #'.whichSegment'.")
		comment ("Choose a phonemic transcription.")
		choice ("Rating", 1)
		option ("Correct")
		option ("Incorrect")
	endPause ("Ruin everything", "Rate Production", 2, 1)

	# Prompt for substituted sound
	if rating$ = "Correct"
		.segmentScore = 1
	else
		.segmentScore = 0
	endif

	# Add boundaries and text to the Phonetic, Phonemic, transCheck tiers
	select TextGrid 'transBasename$'
	Insert boundary... gfta_trans_textgrid.prosodicPos 'start_time'
	Insert boundary... gfta_trans_textgrid.prosodicPos 'end_time'
	Insert boundary... gfta_trans_textgrid.phonemic 'start_time'
	Insert boundary... gfta_trans_textgrid.phonemic 'end_time'

	# Add the transcriptions to the TextGrid.
	sound_int = Get interval at time... gfta_trans_textgrid.phonemic 'interval_mid'
	Set interval text... gfta_trans_textgrid.prosodicPos 'sound_int' '.pros$'
	Set interval text... gfta_trans_textgrid.phonemic 'sound_int' '.target$'

	Insert point... gfta_trans_textgrid.score 'interval_mid' '.segmentScore'

	# Notes on the transcription of the word
	beginPause ("Notes")	
		comment ("Any notes on the transcription of this segment?")
		sentence ("trans_notes", "")
	endPause ("Ruin everything", "Finish transcribing this segment", 2, 1)

	if trans_notes$ != ""
		#middle_of_word_time = ('current_word_end' + 'current_word_start') / 2
		Insert point... gfta_trans_textgrid.notes 'interval_mid' 'trans_notes$'
	endif

	# Backup current TextGrid
	select TextGrid 'transBasename$'
#	Save as text file... 'textGridBackup_filepath$'


	# Update the GFTA score.
	@selectTable(transLogBasename$)

	.score = Get value: 1, transLogScore$
	.score = .score + .segmentScore
	Set numeric value: 1, transLogScore$, .score
endproc

procedure transcribe_notes(.trial_number, .word$, .target1$, .target2$)
	beginPause("Transcription Notes")
		@trial_header(.trial_number, .word$, .target1$, .target2$, 0)

		comment("You may enter any notes about this transcription below: ")
		text("transcriber_notes", "")

		comment("Should an audio and textgrid snippet be extracted for this trial?")
		boolean("Extract snippet", 0)
		
	button = endPause("Quit (without saving this trial)", "Transcribe it!", 2, 1)

	if button == 1
		.result_node$ = node_quit$
	else
		.notes$ = transcriber_notes$
		.no_notes = length(.notes$) == 0
		.snippet = extract_snippet
		.result_node$ = node_next$
	endif
endproc

#######################################################################
# PROCEDURE definitions start here

## This function is used to insert a row at the top of a table and write out 
## the name and value of a string variable in that row. It's used for testing 
## to show a "stack" of variable names and their values.
procedure writeLine .variable$
	# Store the value of the passed variable
	.value$ = '.variable$'
	
	# If other objects are selected in Praat, store their names
	.numberOfObjects = numberOfSelected ()	
	if .numberOfObjects > 0
		for i from 1 to .numberOfObjects
			.selection'i'$ = selected$ (i)
		endfor
	endif
	
	# Update the table with passed variable and its value
	select Table testing
	Set string value... 1 variable '.variable$'
	Set string value... 1 value '.value$'
	Insert row... 1
	
	# Restore Praat object selection
	if .numberOfObjects > 0
		select '.selection1$'
		if .numberOfObjects > 1		
			for i from 2 to .numberOfObjects
				.name$ = .selection'i'$
       				plus '.name$'
			endfor
		endif
	endif	
endproc

#### PROCEDURE to load the transcription log file or create the transcription log Table object.
procedure gfta_trans_log(.method$, .task$, .experimental_ID$, .initials$, .directory$, .nTrials)
	# Description of the GFTA Transcription Log.
	# A table with one row and the following columns (values).
	# - GFTATranscriber (string): the initials of the nonword
	#     transcriber.
	# - StartTime (string): the date & time that the transcription began.
	# - EndTime (string): the date & time that the transcription ended.
	# - NumberOfTrials (numeric): the number of trials in the Word
	#     List table.
	# - NumberOfTrialsTranscribed (numeric): the number of trials that
	#     have been transcribed.

	# Numeric and string constants for the GFTA transcription log
	.transcriber = 1
	.transcriber$ = "GFTATranscriber"
	.start = 2
	.start$ = "StartTime"
	.end = 3
	.end$ = "EndTime"
	.trials = 4
	.trials$ = "NumberOfTrials"
	.trials_transcribed = 5
	.trials_transcribed$ = "NumberOfTrialsTranscribed"
	.score = 6
	.score$ = "Score"

	# Concatenate column names argument for the Create Table command
	column_names$ = "'.transcriber$' '.start$' '.end$' '.trials$' '.trials_transcribed$' '.score$'"

	# Filename constants
	audio_basename$ = .experimental_ID$ + "_Audio"
	.basename$ = .task$ + "_" + .experimental_ID$ + "_" + .initials$ + "transLog"
	.filename$ = .basename$ + ".txt"
	.filepath$ = .directory$ + "/" + .filename$
	.exists = fileReadable(.filepath$)

	## Pseudo-methods

	if .method$ == "check"
		# Do nothing. The checking already happened above. But we make a
		# pseudomethod called "check" so we can describe what happens when
		# only the above code is executed.
	endif

	if .method$ == "load"
		if .exists
			Read Table from tab-separated file: .filepath$
		else
			# Initialize the values of the GFTA Transcription Log.
			Create Table with column names: .basename$, 1, column_names$

			#currentTime$ = replace$(date$(), " ", "_", 0)
			@currentTime
			@selectTable(.basename$)

			Set string value: 1, .transcriber$, .initials$
			Set string value: 1, .start$, currentTime.t$
			Set string value: 1, .end$, currentTime.t$
			Set numeric value: 1, .trials_transcribed$, 0
			Set numeric value: 1, .trials$, .nTrials
			Set numeric value: 1, .score$, 0
		endif
	endif
endproc

#### PROCEDURE to load the transcription textgrid file or create the TextGrid object.
procedure gfta_trans_textgrid(.method$, .task$, .experimental_ID$, .initials$, .directory$)
	# Numeric and string constants for the GFTA transcription textgrid
	.prosodicPos = 1
	.phonemic = 2
	.score = 3
	.notes = 4

	.prosodicPos$ = "ProsodicPos"
	.phonemic$ = "Phonemic"
	.score$ = "Score"
	.notes$ = "TransNotes"

	.level_names$ = "'.prosodicPos$' '.phonemic$' '.score$' '.notes$'"

	audio_basename$ = .experimental_ID$ + "_Audio"
	.basename$ = .task$ + "_" + .experimental_ID$ + "_" + .initials$ + "trans"
	.filename$ = .basename$ + ".TextGrid"
	.filepath$ = .directory$ + "/" + .filename$
	.exists = fileReadable(.filepath$)

	## Pseudo-methods

	if .method$ == "check"
		# Do nothing. The checking already happened above. But we make a
		# pseudomethod called "check" so we can describe what happens when
		# only the above code is executed.
	endif

	if .method$ == "load"
		if .exists
			Read from file: .filepath$
		else
			# Initialize the textgrid
			@selectSound(audio_basename$)
			To TextGrid: .level_names$, "'.score$' '.notes$'"
			@selectTextGrid(audio_basename$)
			Rename: .basename$
		endif
	endif
endproc

#### PROCEDURE to count the remaining trials yet to be transribed.
procedure count_remaining_trials(.log_basename$, .row)
	@selectTable(.log_basename$)
	.n_trials = Get value: .row, "NumberOfTrials"
	.n_transcribed = Get value: .row, "NumberOfTrialsTranscribed"
	.n_remaining = .n_trials - .n_transcribed
endproc

#### PROCEDURE to count GFTA wordlist structures for each of the three structure types.
procedure count_GFTA_wordlist_structures(.wordList_table$)
	# Get the number of trials in the Word List table.
	@selectTable(.wordList_table$)
	.nTrials = Get number of rows
endproc

#### PROCEDURE to find xmin and xmax from Table representation of TextGrid
# Find the xboundaries of an interval from a tabular representation of a textgrid
procedure get_xbounds_from_table(.table$, .row)
	@selectTable(.table$)
	.xmin = Get value: .row, "tmin"
	.xmax = Get value: .row, "tmax"
	.xmid = (.xmin + .xmax) / 2
endproc

#### PROCEDURE to get xmin and xmax of interval in TextGrid object from time point 
# Find the xboundaries of a textgrid interval that contains a given point.
# The .point argument is usually the .xmid value obtained from the above
# get_xbounds_from_table procedure.
procedure get_xbounds_in_textgrid_interval(.textgrid$, .tier_num, .point)
	@selectTextGrid(.textgrid$)
	.interval = Get interval at time: .tier_num, .point
	.xmin = Get start point: .tier_num, .interval
	.xmax = Get end point: .tier_num, .interval
	.xmid = (.xmin + .xmax) / 2
endproc