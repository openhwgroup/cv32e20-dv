# TCL script to extract TRL5 coverage metrics from UCDB file
# Usage: vcover load <ucdb_file> -test dummy -run <this_script>
# Sets the instance path via COV_INSTANCE environment variable

# Load the UCDB file (already loaded by vcover command)
# database open -in merged.ucdb  # Not needed as vcover loads it

# Get coverage metrics for the specific instance
set instance "$::env(COV_INSTANCE)"

# Statement/Line Coverage (Questa calls this "statement" coverage)
set stmt_coverage [coverage get -hier $instance -metric statement max]

# Branch Coverage
set branch_coverage [coverage get -hier $instance -metric branch max]

# Condition Coverage
set condition_coverage [coverage get -hier $instance -metric condition max]

# FSM State Coverage (using fstate metric)
set fsm_state_coverage [coverage get -hier $instance -metric fstate max]

# FSM Transition Coverage (using ftrans metric)
set fsm_transition_coverage [coverage get -hier $instance -metric ftrans max]

# Output results in a machine-readable format
puts "STATEMENT:$stmt_coverage"
puts "BRANCH:$branch_coverage"
puts "CONDITION:$condition_coverage"
puts "FSM_STATE:$fsm_state_coverage"
puts "FSM_TRANSITION:$fsm_transition_coverage"

# Close the database (not strictly needed as vcover will exit)
# database close