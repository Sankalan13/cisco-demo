Feature: Edge Cases and Boundary Conditions
  As a system
  I want to handle edge cases correctly
  So that the system remains stable under unusual conditions

  Background:
    Given the microservices are healthy and running

  Scenario: Add maximum realistic quantity to cart
    Given I have a unique user ID
    When I add product "OLJCESPC7Z" to my cart with quantity 100
    And I retrieve my cart contents
    Then my cart should contain 1 items
    And the product "OLJCESPC7Z" should have quantity 100

  Scenario: Search with special characters
    When I search for products with keyword "!@#$%"
    Then I should receive an empty result set

  Scenario: Get cart for user with very long ID
    Given I have a user ID "user_with_very_long_id_1234567890_abcdefghijklmnopqrstuvwxyz_ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    When I retrieve my cart contents
    Then my cart should contain 0 items

  Scenario: Add all available products to single cart
    Given I have a unique user ID
    When I add product "OLJCESPC7Z" to my cart with quantity 1
    And I add product "66VCHSJNUP" to my cart with quantity 1
    And I add product "1YMWWN1N4O" to my cart with quantity 1
    And I add product "L9ECAV7KIM" to my cart with quantity 1
    And I add product "2ZYFJ3GM2N" to my cart with quantity 1
    And I add product "0PUK6V6EV0" to my cart with quantity 1
    And I add product "LS4PSXUNUM" to my cart with quantity 1
    And I add product "9SIQT8TOJO" to my cart with quantity 1
    And I add product "6E92ZMYYFZ" to my cart with quantity 1
    And I retrieve my cart contents
    Then my cart should contain 9 items

  Scenario: Empty cart multiple times
    Given I have a unique user ID
    When I add product "OLJCESPC7Z" to my cart with quantity 1
    And I empty my cart
    And I empty my cart
    And I empty my cart
    And I retrieve my cart contents
    Then my cart should contain 0 items

  Scenario: Get recommendations with maximum cart size
    Given I have a unique user ID
    When I add product "OLJCESPC7Z" to my cart with quantity 1
    And I add product "66VCHSJNUP" to my cart with quantity 1
    And I add product "1YMWWN1N4O" to my cart with quantity 1
    And I add product "L9ECAV7KIM" to my cart with quantity 1
    And I add product "2ZYFJ3GM2N" to my cart with quantity 1
    And I get product recommendations
    Then I should receive product recommendations

  Scenario: Checkout with international address
    Given I have a unique user ID
    When I add product "OLJCESPC7Z" to my cart with quantity 1
    And I request a shipping quote for the following address:
      | field          | value                           |
      | street_address | 221B Baker Street               |
      | city           | London                          |
      | state          | England                         |
      | country        | United Kingdom                  |
      | zip_code       | 12345                           |
    Then I should receive a shipping quote
    And the quote should have a valid cost

  Scenario: Search with single character
    When I search for products with keyword "a"
    Then I should receive search results

  Scenario: Multiple concurrent operations on same cart
    Given I have a unique user ID
    When I add product "OLJCESPC7Z" to my cart with quantity 1
    And I retrieve my cart contents
    And I add product "66VCHSJNUP" to my cart with quantity 1
    And I retrieve my cart contents
    And I add product "9SIQT8TOJO" to my cart with quantity 1
    And I retrieve my cart contents
    Then my cart should contain 3 items

  Scenario: Get product details for all products
    When I get product details for "OLJCESPC7Z"
    Then the product should have valid details
    When I get product details for "66VCHSJNUP"
    Then the product should have valid details
    When I get product details for "9SIQT8TOJO"
    Then the product should have valid details
