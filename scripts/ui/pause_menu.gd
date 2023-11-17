extends Panel

const RANKING_BAR = preload("res://scenes/ui/pause_ranking_bar.tscn")
const RANK_TOOLTIPS = {
	"5K": "Five cards of the same rank.",
	"SF": "%s consecutive cards of the same suit.",
	"4K": "Four cards of the same rank.",
	"FH": "%s cards of one rank, and two of another.",
	"FL": "%s cards of the same suit.",
	"ST": "%s consecutive cards.",
	"3K": "Three cards of the same rank.",
	"2P": "Two cards on one rank, and two of another.",
	"1P": "Two cards of the same rank.",
	"HC": "The single highest card.",
	"WH": "The %s lowest cards.",
	"SW": "The %s lowest cards, all of the same suit.",
	"CR": "Three cards of one rank, and two of another.",
	"3P": "Two cards each of three separate ranks.",
	"2T": "Three cards of one rank, and three of another.",
	"6K": "Six cards of the same rank."
}
const NUM_TO_WORD = {
#	1: "One",
#	2: "Two",
	3: "Three",
	4: "Four",
	5: "Five",
	6: "Six",
}
@onready var rank_holder = %Ranks


func _ready():
	Netgame.state_updated.connect(set_up_rankings)
	
	set_up_rankings()

func set_up_rankings():
	var RANKS: Dictionary = Rules.RULES.HAND_RANKS
	var is_low = Rules.RULES.BALL == -1
	var suits = Rules.RULES.SUITS
	var cph = Rules.RULES.CARDS_PER_HAND
	
	var rank_names = RANKS.keys()
	rank_names.sort_custom(func(a,b): return RANKS[a] > RANKS[b])
	
	rank_names.erase("")
	rank_names.erase("AW")
	
	# Remove changes which are not possible
	if Rules.RULES.WILDS == 0:
		for i in range(cph + 1, 7):
			rank_names.erase(str(i) + "K")
		for i in range(suits + 1, 7):
			rank_names.erase(str(i) + "K")
		if suits < 3:
			rank_names.erase("FH")
			rank_names.erase("CR")
		if (suits < 4 and cph == 6):
			rank_names.erase("FH")
	if cph == 4:
		rank_names.erase("FH")
	
	# Gametype-dependent
	if not is_low:
		rank_names.erase("WH")
		rank_names.erase("SW")
	else:
		rank_names.erase("ST")
		rank_names.erase("FL")
		rank_names.erase("SF")
		
		rank_names.reverse()
	
	var i = 0.0
	var x = rank_names.size()
	
	while rank_holder.get_child_count() > 0:
		rank_holder.get_child(0).free()
	
	for n in rank_names:
		var ranking = RANKING_BAR.instantiate()
		
		var h = Hand.new([])
		h.rank = n
		var full_name = h.get_name().get_slice(" (", 0)
		ranking.get_node("%HandName").text = full_name
		
		var t: String = RANK_TOOLTIPS[n]
		var l = t.find("%s")
		if l > -1:
			var s = ""
			if n == "FH":
				s = NUM_TO_WORD[cph - 2]
			else:
				s = NUM_TO_WORD[cph]
			
			if l > 0:
				s = s.to_lower()
			
			t = t % s
		ranking.tooltip_text = t
		
		var y = ranking.get_theme_stylebox("panel").duplicate()
		y.bg_color = Color.from_hsv(i / x, 0.5, 1 / 3.0)
		ranking.add_theme_stylebox_override("panel", y)
		i += 1
		
		rank_holder.add_child(ranking)
