# editGFTAtable.praat

# Initializing the session.
beginPause ("'procedure$' - Initializing session, steps 1 & 2.")
	# Prompt the user to enter the segmenter's initials.
	comment ("Please enter your initials in the field below.")
  		word    ("Your initials", "")
	# Prompt the segmenter to specify where the segmentation is being done.
	comment ("Please specify where the machine is on which you are working.")
		optionMenu ("Location", 1)
		option ("ShevlinHallLab")
		option ("Other (Beckman)")
button = endPause ("Quit", "Continue", 2)
# Set the value of the segmenters_initials$ variable.
segmenters_initials$ = your_initials$
# Use the value of the 'location$' variable to set up the drive$ variable.
if location$ == "ShevlinHallLab"
	drive$ = "//l2t.cla.umn.edu/tier2/"
elsif location$ == "Other (Beckman)"				
	drive$ = "/Volumes/tier2/"
endif
# Set the value of the 'logfiles_dir$' directory pathname. 
logfiles_dir$ = "'drive$'Segmenting/Segmenters/'segmenters_initials$'/LogsGFTA/"

beginPause ("'procedure$' - Initializing session, steps 2 & 3.")
	# Prompt the segmenter to specify the testwave (i.e., the "TimePoint") of the data.
	comment ("Please specify the test wave of the recording.")
		optionMenu ("Testwave", 1)
			option ("TimePoint1")
			option ("TimePoint2")
			option ("Other")
	# Prompt the segmenter to specify the Experimental_ID for the data.
	comment ("Choose the subject's experimental ID from the menu below.")
	Create Strings as file list... logFiles 'logfiles_dir$'*.txt
# Create Strings as file list... fileList /Volumes/tier2/Segmenting/Segmenters/JA/LogsGFTA/*.txt
	# Create the drop-down menu by looping through the Strings object 'logFiles'.
	# Making a selection from this optionMenu creates the string variable 'experimental_ID$'.
	select Strings logFiles
	n_log_files = Get number of strings
	optionMenu ("Experimental ID", 1)
		for n_file to n_log_files
			select Strings logFiles
			# Get the n-th filename from the Strings object 'logFiles'.
			log_filename$ = Get string... n_file
			experimental_ID$ = extractWord$(log_filename$, "_")
			experimental_ID$ = left$(experimental_ID$, length(experimental_ID$) - 17)
			option ("'experimental_ID$'")
		endfor
	# Clean up by removing the logFiles Strings Object.
	select Strings logFiles
	Remove
button = endPause ("Back", "Quit", "Continue", 3, 1)
# echo 'experimental_ID$'

# Set the value of the 'wordList_file_pathname$' pathname. 
wordList_file_pathname$ = "'drive$'DataAnalysis/GFTA/'testwave$'/WordLists/GFTA_'experimental_ID$'_WordList.txt"

# See if there is an existing WordList file already made. 
file_readable = fileReadable(wordList_file_pathname$)
if (file_readable)
	# If there is, read it in. 
	Read Table from tab-separated file... 'wordList_file_pathname$'
else
	# Otherwise, read in the GFTA_Info.txt table.
	Read Table from tab-separated file... 'drive$'DataAnalysis/GFTA/GFTA_Info.txt
endif
# Rename as WordList so that don't have to adjust
Rename... WordList
n_rows = Get number of rows

# Read in the log file.
logfile_pathname$ = "'logfiles_dir$''log_filename$'"
Read Table from tab-separated file... 'logfile_pathname$'
n_segmented = Get value... 1 NumberOfTrialsSegmented

beginPause ("Specify the original word that needs to be moved and so on")
	comment ("Which word needs to move to later in the list?")
	optionMenu ("Item to move", 'n_segmented'+1)
		for n_word to n_rows
			select Table WordList
			# Get the n-th word.
			item_to_move$ = Get value... n_word ortho
			option ("'item_to_move$'")
		endfor
	comment ("After which other word should it go?")
	optionMenu ("Move to after", 'n_segmented'+2)
		for n_word2 to n_rows
			select Table WordList
			# Get the n-th word.
			move_to_after$ = Get value... n_word2 ortho
			option ("'move_to_after$'")
		endfor
button = endPause ("Back", "Quit", "Continue", 3, 1)

orig_row = Search column... ortho 'item_to_move$'
insert_row = Search column... ortho 'move_to_after$'
insert_row = 'insert_row'+1
Insert row... 'insert_row'

# Get the values of the other 9 elements in the orig_row
orig_word$ = Get value... 'orig_row' word
orig_wb$ = Get value... 'orig_row' wb
orig_stress$ = Get value... 'orig_row' stress
orig_targetC1$ = Get value... 'orig_row' targetC1
orig_targetC2$ = Get value... 'orig_row' targetC2
orig_targetC3$ = Get value... 'orig_row' targetC3
orig_prosPos1$ = Get value... 'orig_row' prosPos1
orig_prosPos2$ = Get value... 'orig_row' prosPos2
orig_prosPos3$ = Get value... 'orig_row' prosPos3

# Set the values of all 10 elements in the insert_row
Set string value... 'insert_row' word 'orig_word$'
Set string value... 'insert_row' wb 'orig_wb$'
Set string value... 'insert_row' ortho 'item_to_move$'
Set string value... 'insert_row' stress 'orig_stress$'
Set string value... 'insert_row' targetC1 'orig_targetC1$'
Set string value... 'insert_row' targetC2 'orig_targetC2$'
Set string value... 'insert_row' targetC3 'orig_targetC3$'
Set string value... 'insert_row' prosPos1 'orig_prosPos1$'
Set string value... 'insert_row' prosPos2 'orig_prosPos1$'
Set string value... 'insert_row' prosPos3 'orig_prosPos3$'

# Remove the original row. 
Remove row... 'orig_row'

# Save the Table Object.
Save as tab-separated file... 'wordList_file_pathname$'

