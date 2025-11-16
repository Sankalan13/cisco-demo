Feature: Product Search Functionality
  As a customer
  I want to search for products
  So that I can find items I'm interested in

  Scenario: Search for products with valid keyword
    When I search for products with keyword "watch"
    Then I should receive search results
    And the results should contain products matching "watch"
    And all returned products should have valid product information

  Scenario: Search with partial keyword match
    When I search for products with keyword "glass"
    Then I should receive search results
    And the results should contain products matching "glass"

  Scenario: Case-insensitive search
    When I search for products with keyword "SUNGLASSES"
    Then I should receive search results
    And the results should contain products matching "sunglasses"

  Scenario: Search with no matching results
    When I search for products with keyword "nonexistentproduct12345"
    Then I should receive an empty result set

  Scenario: Search with empty string
    When I search for products with an empty keyword
    Then I should receive all available products

  Scenario: Verify search results include complete product details
    When I search for products with keyword "kitchen"
    Then I should receive search results
    And each product should have the following fields:
      | field        |
      | id           |
      | name         |
      | description  |
      | picture      |
      | price_usd    |
      | categories   |
