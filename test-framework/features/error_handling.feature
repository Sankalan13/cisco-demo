Feature: Error Handling
  As a system
  I want to handle errors gracefully
  So that users receive meaningful error messages

  Background:
    Given the microservices are healthy and running

  Scenario: Get non-existent product returns error
    When I try to get product with ID "NONEXISTENT123"
    Then I should receive a product not found error

  Scenario: Checkout with invalid credit card
    Given I have a unique user ID
    And I add product "OLJCESPC7Z" to my cart with quantity 1
    When I try to place an order with invalid credit card "0000-0000-0000-0000"
    Then I should receive a payment error

  Scenario: Checkout with expired credit card
    Given I have a unique user ID
    And I add product "OLJCESPC7Z" to my cart with quantity 1
    When I try to place an order with expired credit card year 2020
    Then I should receive a credit card expired error

  Scenario: Service handles invalid product gracefully
    Given I have a unique user ID
    When I add product "INVALID_PRODUCT_ID" to my cart with quantity 1
    And I retrieve my cart contents
    Then my cart should contain 1 items

  Scenario: Service handles negative quantity gracefully
    Given I have a unique user ID
    When I add product "OLJCESPC7Z" to my cart with quantity -5
    And I retrieve my cart contents
    Then my cart should contain 1 items

  Scenario: Service handles empty cart checkout gracefully
    Given I have a unique user ID
    When I place an order with valid payment and shipping information
    Then the order should be placed successfully

  Scenario: Service handles empty city in shipping address
    Given I have a unique user ID
    And I add product "OLJCESPC7Z" to my cart with quantity 1
    When I request a shipping quote for the following address:
      | field          | value           |
      | street_address | 123 Test St     |
      | city           |                 |
      | state          | CA              |
      | country        | United States   |
      | zip_code       | 12345           |
    Then I should receive a shipping quote
