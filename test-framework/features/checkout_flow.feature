Feature: Checkout and Payment Flow
  As a customer
  I want to complete the checkout process
  So that I can purchase items in my cart

  Background:
    Given the microservices are healthy and running

  Scenario: Complete end-to-end checkout with payment
    Given I have a unique user ID
    And I add product "OLJCESPC7Z" to my cart with quantity 2
    And I add product "66VCHSJNUP" to my cart with quantity 1
    When I place an order with the following details:
      | field           | value                    |
      | email           | test@example.com         |
      | street_address  | 1600 Amphitheatre Parkway|
      | city            | Mountain View            |
      | state           | CA                       |
      | country         | United States            |
      | zip_code        | 94043                    |
      | card_number     | 4432-8015-6152-0454      |
      | card_cvv        | 672                      |
      | card_exp_month  | 1                        |
      | card_exp_year   | 2030                     |
      | currency_code   | USD                      |
    Then the order should be placed successfully
    And I should receive an order ID
    And I should receive a shipping tracking ID
    And my cart should be empty

  Scenario: Multi-item checkout with currency conversion
    Given I have a unique user ID
    And I add product "OLJCESPC7Z" to my cart with quantity 1
    And I add product "9SIQT8TOJO" to my cart with quantity 2
    When I place an order with EUR currency and valid shipping and payment details
    Then the order should be placed successfully
    And I should receive an order ID in EUR
    And I should receive a shipping tracking ID
    And the total cost should be in EUR

  Scenario: Checkout with single item
    Given I have a unique user ID
    And I add product "66VCHSJNUP" to my cart with quantity 1
    When I place an order with valid payment and shipping information
    Then the order should be placed successfully
    And I should receive an order ID
    And I should receive a shipping tracking ID
    And my cart should be empty
