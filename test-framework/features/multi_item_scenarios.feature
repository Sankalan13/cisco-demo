Feature: Multi-Item Scenarios
  As a customer
  I want to work with multiple items across different services
  So that I can complete complex shopping workflows

  Background:
    Given the microservices are healthy and running

  Scenario: Get product recommendations and add to cart
    Given I have a unique user ID
    When I add product "OLJCESPC7Z" to my cart with quantity 1
    And I get product recommendations
    Then I should receive product recommendations
    And the recommendations should not include products already in my cart

  Scenario: Calculate shipping for cart with multiple items
    Given I have a unique user ID
    When I add product "OLJCESPC7Z" to my cart with quantity 2
    And I add product "66VCHSJNUP" to my cart with quantity 3
    And I add product "9SIQT8TOJO" to my cart with quantity 1
    And I request a shipping quote for the following address:
      | field          | value                    |
      | street_address | 1600 Amphitheatre Parkway|
      | city           | Mountain View            |
      | state          | CA                       |
      | country        | United States            |
      | zip_code       | 94043                    |
    Then I should receive a shipping quote
    And the quote should have a valid cost

  Scenario: Browse products, add to cart, and checkout
    Given I have a unique user ID
    When I search for products with keyword "kitchen"
    Then I should receive search results
    When I add product "9SIQT8TOJO" to my cart with quantity 2
    And I add product "LS4PSXUNUM" to my cart with quantity 1
    And I retrieve my cart contents
    Then my cart should contain 2 items
    When I place an order with valid payment and shipping information
    Then the order should be placed successfully
    And I should receive an order ID
    And my cart should be empty

  Scenario: Add all product categories to cart
    Given I have a unique user ID
    When I add product "OLJCESPC7Z" to my cart with quantity 1
    And I add product "66VCHSJNUP" to my cart with quantity 1
    And I add product "L9ECAV7KIM" to my cart with quantity 1
    And I add product "2ZYFJ3GM2N" to my cart with quantity 1
    And I add product "9SIQT8TOJO" to my cart with quantity 1
    And I retrieve my cart contents
    Then my cart should contain 5 items

  Scenario: Get recommendations for empty cart
    Given I have a unique user ID
    When I get product recommendations
    Then I should receive product recommendations
