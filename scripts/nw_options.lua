--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

function onInit()
	OptionsManager.registerOption2('WARN_COST', false, 'option_header_game', 'opt_lab_warn_cost', 'option_entry_cycler', 
		{ labels = 'nw_opt_off|nw_opt_on', values = 'off|on', default = 'off' })
end