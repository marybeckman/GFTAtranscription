#######################################################################
# Controls whether the @log_[...] procedures write to the InfoLines.
# debug_mode = 1
debug_mode = 0
continueTranscription = 1

include check_version.praat
include ../Utilities/L2T-Utilities.praat
include ../Audio/L2T-Audio.praat
include ../StartupForm/L2T-StartupForm.praat
include ../WordList/L2T-WordList.praat
include ../L2T-SegmentationTextGrid/L2T-SegmentationTextGrid.praat
include ../L2T-Transcription/L2T-Transcription.praat

# Set the session parameters.
defaultExpTask = 3
defaultTestwave = 1
defaultActivity = 3
@session_parameters: defaultExpTask, defaultTestwave, defaultActivity

# Load the audio file
@audio

# Load the WordList.
@wordlist

# Load the checked segmented TextGrid.
@segmentation_textgrid

# Set the transcription-specific parameters.
@transcription_parameters

# Numeric and string constants for the Word List Table.
wordListBasename$ = wordlist.praat_obj$
wordListWorldBet$ = wordlist_columns.worldBet$
wordListTargetC1$ = wordlist_columns.targetC1$
wordListTargetC2$ = wordlist_columns.targetC2$
wordListTargetC3$ = wordlist_columns.targetC3$
wordListprosPos1$ = wordlist_columns.prosPos1$
wordListprosPos2$ = wordlist_columns.prosPos2$
wordListprosPos3$ = wordlist_columns.prosPos3$

#wordListprosPos3$ = startup_GFTA_wordlist.prosPos3$

# Column numbers from the segmented textgrid
segTextGridTrial = segmentation_textgrid_tiers.trial
segTextGridContext = segmentation_textgrid_tiers.context

# Count the trials of structure type
@count_GFTA_wordlist_structures(wordListBasename$)
nTrials = count_GFTA_wordlist_structures.nTrials

@participant: audio.read_from$, session_parameters.participant_number$

# Check whether the log and textgrid exist already
@transcription_log("check", session_parameters.experimental_task$, participant.id$, session_parameters.initials$, transcription_parameters.logDirectory$, nTrials, 0, 0)
@transcription_textgrid("check", session_parameters.experimental_task$, participant.id$, session_parameters.initials$, transcription_parameters.textGridDirectory$))

# Load or initialize the transcription log/textgrid iff
# the log/textgrid both exist already or both need to be created.
if transcription_log.exists == transcription_textgrid.exists
	@transcription_log("load", session_parameters.experimental_task$, participant.id$, session_parameters.initials$, transcription_parameters.logDirectory$, nTrials, 0, 0)
	@transcription_textgrid("load", session_parameters.experimental_task$, participant.id$, session_parameters.initials$, transcription_parameters.textGridDirectory$)
# Otherwise exit with an error message
else
	log_part$ = "Log " + transctiption_log.filename$
	grid_part$ = "TextGrid " + transcription_textgrid.filename$
	if transcrtiption_log.exists
		msg$ = "Initialization error: " + log_part$ + "was found, but " + grid_part$ + " was not."
	else
		msg$ = "Initialization error: " + grid_part$ + "was found, but " + log_part$ + " was not."
	endif
	exitScript: msg$
endif

# Export values to global namespace
segmentBasename$ = segmentation_textgrid.praat_obj$
segmentTableBasename$ = segmentation_textgrid.tablePraat_obj$
audioBasename$ = audio.praat_obj$
transBasename$ = transcription_textgrid.praat_obj$
transLogBasename$ = transcription_log.praat_obj$

# These are column names
transLogTrials$ = transcription_log.trials$
transLogTrialsTranscribed$ = transcription_log.trials_transcribed$
transLogEndTime$ = transcription_log.end$
transLogScore$ = transcription_log.score$

###############################################################################
#                             Code for Transcription                                #
###############################################################################

# Open an Edit window with the segmentation textgrid, so that the transcriber can examine
# the larger segmentation context to recoup from infelicitous segmenting of false starts
# and the like. 
selectObject(segmentBasename$)
Edit

# Open a separate Editor window with the transcription textgrid object and audio file.
selectObject(transBasename$)
plusObject(audioBasename$)
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

selectObject(segmentTableBasename$)
Extract rows where column (text): "tier", "is equal to", "Trial"
Rename: "TierTimes"

# Loop through the trials of the current type
while (currentTrial <= n_trials & continueTranscription)
	# Look up trial number in segmentation table. Compute trial midpoint from table.
	select Table TierTimes
	.table_obj$ = selected$ ()
	@get_xbounds_from_table(.table_obj$, currentTrial)
	trialXMid = get_xbounds_from_table.xmid

	# Find bounds of the textgrid interval containing the trial midpoint
	@get_xbounds_in_textgrid_interval(segmentBasename$, segTextGridTrial, trialXMid)

	# Use the XMin and XMax of the current trial to extract that portion of the segmented 
	# TextGrid, preserving the times. The TextGrid Object that this operation creates will 
	# have the name:
	# ::ExperimentalTask::_::ExperimentalID::_::SegmentersInitials::segm_part
	selectObject(segmentBasename$)
	Extract part: get_xbounds_in_textgrid_interval.xmin, get_xbounds_in_textgrid_interval.xmax, "yes"

	# Convert the (extracted) TextGrid to a Table, which has the
	# same name as the TextGrid from which it was created.
	selectObject(segmentBasename$ + "_part")
	Down to Table: "no", 6, "yes", "no"
	selectObject(segmentBasename$ + "_part")
	Remove

	# Subset the 'segmentBasename$'_part Table to just the intervals on the Context Tier.
	selectObject(segmentTableBasename$ + "_part")
	Extract rows where column (text): "tier", "is equal to", "Context"
	selectObject(segmentTableBasename$ + "_part")
	Remove

	# Count the number of segmented intervals.
	selectObject(segmentTableBasename$ + "_part_Context")
	numResponses = Get number of rows
	# If there is more than one segmented interval, ...
	if numResponses > 1
		# Zoom to the entire trial in the segmentation TextGrid object and 
		# invite the transcriber to select the interval to transcribe.
		editor 'segmentBasename$'
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
	selectObject(segmentTableBasename$ + "_part_Context")
	contextLabel$ = Get value: repetition_number, "text"

	# Determine the XMin and XMax of the segmented interval.
	@get_xbounds_from_table(segmentTableBasename$ + "_part_Context", repetition_number)
	segmentXMid = get_xbounds_from_table.xmid

	@get_xbounds_in_textgrid_interval(segmentBasename$, segTextGridContext, segmentXMid)
	segmentXMin = get_xbounds_in_textgrid_interval.xmin
	segmentXMax = get_xbounds_in_textgrid_interval.xmax

	# Add interval boundaries on each tier.
	selectObject(transBasename$)
	Insert boundary: transcription_textgrid.prosodicPos, segmentXMin
	Insert boundary: transcription_textgrid.prosodicPos, segmentXMax
	Insert boundary: transcription_textgrid.phonemic, segmentXMin
	Insert boundary: transcription_textgrid.phonemic, segmentXMax

	# Determine the target word and target segments. 
	selectObject(wordListBasename$)
	targetWord$ = Get value: currentTrial, wordListWorldBet$
	targetC1$ = Get value: currentTrial, wordListTargetC1$
	targetC2$ = Get value: currentTrial, wordListTargetC2$
	targetC3$ = Get value: currentTrial, wordListTargetC3$
	prosPos1$ = Get value: currentTrial, wordListprosPos1$
	prosPos2$ = Get value: currentTrial, wordListprosPos2$
	prosPos3$ = Get value: currentTrial, wordListprosPos3$

	if targetC1$ != "" & targetC1$ != "?" 
		@TranscribeSegment(targetC1$, prosPos1$, currentTrial, 1, targetWord$)
	endif
	if targetC2$ != "" & targetC2$ != "?" 
		@TranscribeSegment(targetC2$, prosPos2$, currentTrial, 2, targetWord$)
	endif
	if targetC3$ != "" & targetC3$ != "?"
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
		selectObject(segmentTableBasename$ + "_part_Context")
		Remove
	endif

	selectObject(transBasename$)
	Save as text file: transcription_textgrid.filepath$

	selectObject(transLogBasename$)
	@currentTime
	Set string value: 1, transLogEndTime$, currentTime.t$
	Set numeric value: 1, transLogTrialsTranscribed$, currentTrial
	Save as tab-separated file: transcription_log.filepath$

	#increment trial number
	currentTrial = currentTrial + 1
endwhile

select all
Remove

procedure TranscribeSegment(.target$, .pros$, .currentTrial, .whichSegment, .word$)
	# Zoom to the segmented interval in the editor window.
	editor 'transBasename$'
		Zoom: segmentXMin - 0.25, segmentXMax + 0.25
	endeditor

	beginPause ("Make a selection in the editor window")
#		comment ("Next sound to transcribe: '.target$'")
		comment ("Next sound to transcribe: '.target$' at '.pros$' in '.word$'")
		comment ("Please select the whole sound in the editor window")
	clicked = endPause ("Ruin everything", "Continue to transcribe this sound", 2, 1)

	editor 'transBasename$'
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
	selectObject(transBasename$)
	Insert boundary... transcription_textgrid.prosodicPos 'start_time'
	Insert boundary... transcription_textgrid.prosodicPos 'end_time'
	Insert boundary... transcription_textgrid.phonemic 'start_time'
	Insert boundary... transcription_textgrid.phonemic 'end_time'

	# Add the transcriptions to the TextGrid.
	sound_int = Get interval at time... transcription_textgrid.phonemic 'interval_mid'
	Set interval text... transcription_textgrid.prosodicPos 'sound_int' '.pros$'
	Set interval text... transcription_textgrid.phonemic 'sound_int' '.target$'

	Insert point... transcription_textgrid.score 'interval_mid' '.segmentScore'

	# Notes on the transcription of the word
	beginPause ("Notes")	
		comment ("Any notes on the transcription of this segment?")
		sentence ("trans_notes", "")
	endPause ("Ruin everything", "Finish transcribing this segment", 2, 1)

	if trans_notes$ != ""
		#middle_of_word_time = ('current_word_end' + 'current_word_start') / 2
		Insert point... transcription_textgrid.notes 'interval_mid' 'trans_notes$'
	endif

	# Backup current TextGrid
	selectObject(transBasename$)
#	Save as text file... 'textGridBackup_filepath$'


	# Update the GFTA score.
	selectObject(transLogBasename$)

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

#### PROCEDURE to count the remaining trials yet to be transribed.
procedure count_remaining_trials(.log_basename$, .row)
	selectObject(.log_basename$)
	.n_trials = Get value: .row, "NumberOfTrials"
	.n_transcribed = Get value: .row, "NumberOfTrialsTranscribed"
	.n_remaining = .n_trials - .n_transcribed
endproc

#### PROCEDURE to count GFTA wordlist structures for each of the three structure types.
procedure count_GFTA_wordlist_structures(.wordList_table$)
	# Get the number of trials in the Word List table.
	selectObject(.wordList_table$)
	.nTrials = Get number of rows
endproc

#### PROCEDURE to find xmin and xmax from Table representation of TextGrid
# Find the xboundaries of an interval from a tabular representation of a textgrid
procedure get_xbounds_from_table(.table$, .row)
	selectObject(.table$)
	.xmin = Get value: .row, "tmin"
	.xmax = Get value: .row, "tmax"
	.xmid = (.xmin + .xmax) / 2
endproc

#### PROCEDURE to get xmin and xmax of interval in TextGrid object from time point 
# Find the xboundaries of a textgrid interval that contains a given point.
# The .point argument is usually the .xmid value obtained from the above
# get_xbounds_from_table procedure.
procedure get_xbounds_in_textgrid_interval(.textgrid$, .tier_num, .point)
	selectObject(.textgrid$)
	.interval = Get interval at time: .tier_num, .point
	.xmin = Get start point: .tier_num, .interval
	.xmax = Get end point: .tier_num, .interval
	.xmid = (.xmin + .xmax) / 2
endproc