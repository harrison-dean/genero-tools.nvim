# genero-tools.nvim

## description
A Neovim plugin to provide some LSP-like functionalities for the Genero language by FourJs.

## config
There are some (TODO more) basic config settings. Below are defaults
'''
GeneroTools.config = {
	options = {
		heart = false,                  -- display ascii heart on F5 (compile)
		hover_define = true,            -- display popup define box on CursorHold
		hover_define_insert = false,    -- display popup define box on CursorHoldI
	},
	mappings = {
		basic = true,                   -- use default basic mappings
	}
}

'''

## functionalities
Below are the functionalities this plugin provides for the Genero language:
* Diagnostics generated from fglcomp/fglform compiler output
* Compile and generate diagnostics on file write (BufWritePost) or F5
* Find type definition of various things under cursor:
  * Variables (beginning with "m_", "l_", "p_"
  * Functions (defined in current file or externally)
  * Tables (following "LIKE "). This one varies as it runs SQL to find the column definitions of the table and outputs it to the popup window
* Various useful keymappings:
  * Normal mode:
    * "key" - Input an elec_key to find it's current value
    * "," / "." - Cycle backwards/forwards through temp tags ("TMP*")
    * F1 - Insert temp tag for current user e.g. TMPHD for hdean
    * F2 - Insert temporary "display" statement to print variable value
    * F3 - Insert CALL elt_debug line with input string
    * F4 - Insert lines to define l_debug_str and cCALL elt_debug(l_debug_str) to debug input variable value
    * F5 - Compile current file, generate diagnostics, and display compiler output in popup window
    * <Space>d - Popup definition line for word under cursor
