Feature: Payment Processing
  As a system
  I want to process payments securely
  So that customer transactions are handled correctly

  Background:
    Given the microservices are healthy and running

  Scenario: Charge valid credit card with USD
    When I charge 50.00 "USD" with valid credit card
    Then the payment should be successful
    And I should receive a transaction ID

  Scenario: Charge valid credit card with EUR
    When I charge 100.00 "EUR" with valid credit card
    Then the payment should be successful
    And I should receive a transaction ID

  Scenario: Charge valid credit card with JPY
    When I charge 5000 "JPY" with valid credit card
    Then the payment should be successful
    And I should receive a transaction ID

  Scenario: Charge small amount (1 USD)
    When I charge 1.00 "USD" with valid credit card
    Then the payment should be successful
    And I should receive a transaction ID

  Scenario: Charge large amount (1000 USD)
    When I charge 1000.00 "USD" with valid credit card
    Then the payment should be successful
    And I should receive a transaction ID

  Scenario: Charge with decimal cents (99.99 USD)
    When I charge 99.99 "USD" with valid credit card
    Then the payment should be successful
    And I should receive a transaction ID

  Scenario: Charge with different valid card number
    When I charge 75.50 "USD" with credit card number "5555-5555-5555-4444"
    Then the payment should be successful
    And I should receive a transaction ID

  Scenario: Multiple successive charges
    When I charge 10.00 "USD" with valid credit card
    And I charge 20.00 "USD" with valid credit card
    And I charge 30.00 "USD" with valid credit card
    Then the payment should be successful
    And I should receive a transaction ID
