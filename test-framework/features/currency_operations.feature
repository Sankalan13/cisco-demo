Feature: Currency Operations
  As a system
  I want to handle currency conversions
  So that users can view prices in their preferred currency

  Background:
    Given the microservices are healthy and running

  Scenario: Get list of supported currencies
    When I request the list of supported currencies
    Then I should receive a list of currency codes
    And the list should contain at least 5 currencies

  Scenario: Verify USD is in supported currencies list
    When I request the list of supported currencies
    Then the list should contain "USD"

  Scenario: Convert 100 USD to EUR
    When I convert 100 "USD" to "EUR"
    Then I should receive a valid conversion result
    And the converted amount should be in "EUR"
    And the converted amount should be greater than 0

  Scenario: Convert 50 EUR to JPY
    When I convert 50 "EUR" to "JPY"
    Then I should receive a valid conversion result
    And the converted amount should be in "JPY"
    And the converted amount should be greater than 0

  Scenario: Convert 200 USD to CAD
    When I convert 200 "USD" to "CAD"
    Then I should receive a valid conversion result
    And the converted amount should be in "CAD"
    And the converted amount should be greater than 0

  Scenario: Convert same currency returns same amount
    When I convert 100 "USD" to "USD"
    Then I should receive a valid conversion result
    And the converted amount should be in "USD"
    And the converted amount should equal 100 units

  Scenario: Convert with decimal amounts
    When I convert 99.99 "USD" to "EUR"
    Then I should receive a valid conversion result
    And the converted amount should be in "EUR"
    And the converted amount should be greater than 0
