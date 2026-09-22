@smoke
Feature: Fixture form
  Background:
    Given the app is running in the integration environment
  Scenario: Submit a name
    When I tap the widget keyed "name_field"
    And I enter "Ada" into the widget keyed "name_field"
    And I tap the widget keyed "submit"
    Then the widget keyed "result" is visible
    And the exact text "Complete" appears exactly 1 times
    And the widget keyed "missing" is absent
