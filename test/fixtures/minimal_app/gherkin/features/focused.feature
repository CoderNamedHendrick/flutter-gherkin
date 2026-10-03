Feature: Focused search
  Scenario: Search without a field key
    Given the app is running in the integration environment
    When I tap the widget keyed "open_search"
    And I enter "movie" into the focused field
    Then the exact text "Query: movie" is visible
    When I enter "" into the focused field
    Then the exact text "Query: " is visible
