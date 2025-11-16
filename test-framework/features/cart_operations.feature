Feature: Cart Operations
  As a customer
  I want to manage items in my shopping cart
  So that I can control what I purchase

  Background:
    Given the microservices are healthy and running

  Scenario: Add multiple different items to cart
    Given I have a unique user ID
    When I add product "OLJCESPC7Z" to my cart with quantity 2
    And I add product "66VCHSJNUP" to my cart with quantity 1
    And I add product "9SIQT8TOJO" to my cart with quantity 3
    And I retrieve my cart contents
    Then my cart should contain 3 items
    And the cart should have all added products

  Scenario: Add same item multiple times
    Given I have a unique user ID
    When I add product "OLJCESPC7Z" to my cart with quantity 1
    And I add product "OLJCESPC7Z" to my cart with quantity 2
    And I retrieve my cart contents
    Then my cart should contain 1 items
    And the product "OLJCESPC7Z" should have quantity 3

  Scenario: Empty cart after adding items
    Given I have a unique user ID
    When I add product "OLJCESPC7Z" to my cart with quantity 2
    And I add product "66VCHSJNUP" to my cart with quantity 1
    And I empty my cart
    And I retrieve my cart contents
    Then my cart should contain 0 items

  Scenario: Get cart for new user returns empty cart
    Given I have a unique user ID
    When I retrieve my cart contents
    Then my cart should contain 0 items

  Scenario: Cart persistence across multiple operations
    Given I have a unique user ID
    When I add product "OLJCESPC7Z" to my cart with quantity 1
    And I retrieve my cart contents
    Then my cart should contain 1 items
    When I add product "66VCHSJNUP" to my cart with quantity 2
    And I retrieve my cart contents
    Then my cart should contain 2 items
    When I add product "1YMWWN1N4O" to my cart with quantity 1
    And I retrieve my cart contents
    Then my cart should contain 3 items

  Scenario: Add items with large quantities
    Given I have a unique user ID
    When I add product "OLJCESPC7Z" to my cart with quantity 10
    And I add product "66VCHSJNUP" to my cart with quantity 20
    And I retrieve my cart contents
    Then my cart should contain 2 items
    And the product "OLJCESPC7Z" should have quantity 10
    And the product "66VCHSJNUP" should have quantity 20

  Scenario: Verify cart contains correct product IDs
    Given I have a unique user ID
    When I add product "L9ECAV7KIM" to my cart with quantity 1
    And I add product "2ZYFJ3GM2N" to my cart with quantity 1
    And I add product "0PUK6V6EV0" to my cart with quantity 1
    And I retrieve my cart contents
    Then my cart should contain 3 items
    And the cart should contain product "L9ECAV7KIM"
    And the cart should contain product "2ZYFJ3GM2N"
    And the cart should contain product "0PUK6V6EV0"
