# test Genero file

MAIN
	DEFINE l_test	SMALLINT
	DEFINE l_string	STRING
	DEFINE l_date	DATETIME


	LET l_test = 2
	LET l_string = test_func(l_test)
	LET l_date = CURRENT

	DISPLAY l_string
	DISPLAY l_date

END MAIN


#
# Function test_func
# -------------------
# Parameters	:
#
# Returns		:
#
# Description of the function
#
FUNCTION test_func(p_test)
	DEFINE p_test	SMALLINT
	
	DEFINE l_string	STRING
	DEFINE	l_test	STRING
    DEFINE	l_ret    STRING

	CALL elt_debug("In test_func()")
	
	LET l_string = "test ", p_test

	LET l_test = l_string, l_string

	LET l_ret = l_string, l_test

	CALL elt_debug("End test_func()")

	RETURN l_ret
END FUNCTION { test_func }
