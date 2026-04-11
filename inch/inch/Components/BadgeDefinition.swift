// MARK: - BadgeDefinition

struct BadgeDefinition {
    let id: String
    let label: String
    let category: String     // must match a key handled by achievementStyle(for:)
    let description: String  // shown in the detail sheet
    let hidden: Bool         // hidden badges don't appear on the shelf until earned

    init(id: String, label: String, category: String, description: String, hidden: Bool = false) {
        self.id = id
        self.label = label
        self.category = category
        self.description = description
        self.hidden = hidden
    }

    /// All static (non-enrolment-dependent) badge definitions in display order.
    static let staticBadges: [BadgeDefinition] = [
        // Milestones
        BadgeDefinition(id: "first_workout",    label: "First Workout",    category: "milestone",    description: "Complete your first workout session"),
        BadgeDefinition(id: "first_test",       label: "First Test",       category: "milestone",    description: "Pass your first level test"),
        BadgeDefinition(id: "program_complete", label: "Program Complete", category: "milestone",    description: "Complete all levels across every exercise"),
        // Streaks
        BadgeDefinition(id: "streak_3",   label: "3-Day Streak",   category: "streak", description: "Train on 3 consecutive days"),
        BadgeDefinition(id: "streak_7",   label: "7-Day Streak",   category: "streak", description: "Maintain a 7-day training streak"),
        BadgeDefinition(id: "streak_14",  label: "14-Day Streak",  category: "streak", description: "Maintain a 14-day training streak"),
        BadgeDefinition(id: "streak_30",  label: "30-Day Streak",  category: "streak", description: "Maintain a 30-day training streak"),
        BadgeDefinition(id: "streak_60",  label: "60-Day Streak",  category: "streak", description: "Maintain a 60-day training streak"),
        BadgeDefinition(id: "streak_100", label: "100-Day Streak", category: "streak", description: "Maintain a 100-day training streak"),
        // Consistency
        BadgeDefinition(id: "sessions_5",   label: "5 Sessions",   category: "consistency", description: "Complete 5 training sessions"),
        BadgeDefinition(id: "sessions_10",  label: "10 Sessions",  category: "consistency", description: "Complete 10 training sessions"),
        BadgeDefinition(id: "sessions_25",  label: "25 Sessions",  category: "consistency", description: "Complete 25 training sessions"),
        BadgeDefinition(id: "sessions_50",  label: "50 Sessions",  category: "consistency", description: "Complete 50 training sessions"),
        BadgeDefinition(id: "sessions_100", label: "100 Sessions", category: "consistency", description: "Complete 100 training sessions"),
        // Journey
        BadgeDefinition(id: "the_full_set",  label: "The Full Set",  category: "journey", description: "Train every enrolled exercise in one week"),
        BadgeDefinition(id: "test_gauntlet", label: "Test Gauntlet", category: "journey", description: "Pass level tests in 3 or more exercises"),
        // Community
        BadgeDefinition(id: "community_top_half",       label: "Top Half",       category: "community", description: "Reach the top 50% in any exercise"),
        BadgeDefinition(id: "community_upper_quarter",  label: "Upper Quarter",  category: "community", description: "Reach the top 25% in any exercise"),
        BadgeDefinition(id: "community_top_10",         label: "Top 10%",        category: "community", description: "Reach the top 10% in any exercise"),
        BadgeDefinition(id: "community_iron_streak",    label: "Iron Streak",    category: "community", description: "Your streak is in the top 10% of all users"),
        BadgeDefinition(id: "community_volume_machine", label: "Volume Machine", category: "community", description: "Top 10% by total volume"),
        BadgeDefinition(id: "community_dedicated",      label: "Dedicated",      category: "community", description: "More dedicated than 75% of users"),
        BadgeDefinition(id: "community_veteran",        label: "Veteran",        category: "community", description: "Top 10% by total workouts"),
        // Time of Day
        BadgeDefinition(id: "time_early_bird",   label: "Early Bird",          category: "time", description: "The world is still sleeping"),
        BadgeDefinition(id: "time_dawn_patrol",  label: "Dawn Patrol",         category: "time", description: "First light, first rep"),
        BadgeDefinition(id: "time_5am_club",     label: "5am Club",            category: "time", description: "Discipline has an alarm clock"),
        BadgeDefinition(id: "time_lunch_legend", label: "Lunch Break Legend",  category: "time", description: "Gains between meetings"),
        BadgeDefinition(id: "time_night_owl",    label: "Night Owl",           category: "time", description: "The gym never closes"),
        BadgeDefinition(id: "time_all_hours",    label: "Sunrise to Sunset",   category: "time", description: "Any hour is workout hour"),
        // Seasonal
        BadgeDefinition(id: "seasonal_january",   label: "January Persistence", category: "seasonal", description: "Most resolutions don't survive January. Yours did.", hidden: true),
        BadgeDefinition(id: "seasonal_summer",    label: "Summer Shape-Up",     category: "seasonal", description: "Summer body, built by summer",                    hidden: true),
        BadgeDefinition(id: "seasonal_winter",    label: "Winter Warrior",      category: "seasonal", description: "Cold outside, fire inside",                       hidden: true),
        BadgeDefinition(id: "seasonal_year_round", label: "Year-Round",         category: "seasonal", description: "No off-season",                                   hidden: true),
        // Holiday
        BadgeDefinition(id: "holiday_new_year",    label: "New Year, New You",       category: "holiday", description: "Starting the year right",                        hidden: true),
        BadgeDefinition(id: "holiday_valentine",   label: "Valentine's Flex",        category: "holiday", description: "Self-love is the best love",                     hidden: true),
        BadgeDefinition(id: "holiday_leap_day",    label: "Leap Day Legend",         category: "holiday", description: "Once every four years — you showed up",          hidden: true),
        BadgeDefinition(id: "holiday_st_patrick",  label: "St. Patrick's Strength",  category: "holiday", description: "Lucky? No, disciplined",                         hidden: true),
        BadgeDefinition(id: "holiday_easter",      label: "Easter Riser",            category: "holiday", description: "Risen and repping",                              hidden: true),
        BadgeDefinition(id: "holiday_independence", label: "Independence Rep",        category: "holiday", description: "Freedom to push harder",                         hidden: true),
        BadgeDefinition(id: "holiday_halloween",   label: "Halloween Grind",         category: "holiday", description: "No rest for the wicked",                         hidden: true),
        BadgeDefinition(id: "holiday_thanksgiving", label: "Turkey Burner",          category: "holiday", description: "Earning the second plate",                       hidden: true),
        BadgeDefinition(id: "holiday_christmas",   label: "Christmas Gains",         category: "holiday", description: "Unwrapping potential",                           hidden: true),
        BadgeDefinition(id: "holiday_nye",         label: "New Year's Eve Send-Off", category: "holiday", description: "Finishing strong",                               hidden: true),
        BadgeDefinition(id: "holiday_friday_13",   label: "Friday the 13th",         category: "holiday", description: "Superstition? Never heard of it.",               hidden: true),
        // Fun
        BadgeDefinition(id: "fun_century_club",       label: "Century Club",       category: "fun", description: "Triple digits",                        hidden: true),
        BadgeDefinition(id: "fun_thousand_repper",    label: "Thousand Repper",    category: "fun", description: "A thousand times, and counting",        hidden: true),
        BadgeDefinition(id: "fun_ten_thousand",       label: "Ten Thousand",       category: "fun", description: "Dedication has a number",               hidden: true),
        BadgeDefinition(id: "fun_full_roster",        label: "Full Roster",        category: "fun", description: "No muscle left behind",                 hidden: true),
        BadgeDefinition(id: "fun_perfect_week",       label: "Perfect Week",       category: "fun", description: "Seven for seven",                      hidden: true),
        BadgeDefinition(id: "fun_triple_threat",      label: "Triple Threat",      category: "fun", description: "Variety is strength",                  hidden: true),
        BadgeDefinition(id: "fun_five_a_day",         label: "Five-a-Day",         category: "fun", description: "Overachiever (complimentary)",          hidden: true),
        BadgeDefinition(id: "fun_plank_minutes",      label: "Plank Minutes",      category: "fun", description: "600 seconds of character",              hidden: true),
        BadgeDefinition(id: "fun_metronome_master",   label: "Metronome Master",   category: "fun", description: "Rhythm and reps",                      hidden: true),
        BadgeDefinition(id: "fun_test_day_ace",       label: "Test Day Ace",       category: "fun", description: "Clutch performer",                     hidden: true),
        BadgeDefinition(id: "fun_level_up_trifecta",  label: "Level Up Trifecta",  category: "fun", description: "Broad-based strength",                 hidden: true),
        BadgeDefinition(id: "fun_maxed_out",          label: "Maxed Out",          category: "fun", description: "Peak progression",                     hidden: true),
        BadgeDefinition(id: "fun_grand_master",       label: "Grand Master",       category: "fun", description: "The summit of summits",                hidden: true),
        BadgeDefinition(id: "fun_groundhog_day",      label: "Groundhog Day",      category: "fun", description: "Didn't he do this yesterday?",         hidden: true),
    ]
}
