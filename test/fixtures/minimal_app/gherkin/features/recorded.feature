# Automated fixture instrumentation smoke, not a human recording acceptance claim.
Feature: Captured fixture form
  Scenario: Replay captured actions
    Given the app is running in the integration environment
    When I tap the widget keyed "name_field"
    And I enter "Ada" into the widget keyed "name_field"
    And I tap the widget keyed "submit"
    Then the widget keyed "result" is visible
