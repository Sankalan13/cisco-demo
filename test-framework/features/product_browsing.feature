Feature: Product Browsing and Cart Management
  As a customer
  I want to browse products and add them to my cart
  So that I can prepare for checkout

  Scenario: Browse products and add item to cart
    When I list all available products
    Then I should receive a non-empty product list
    When I get details for the first product
    Then I should receive complete product information
    When I add the product to my cart with quantity 2
    Then the item should be added successfully
    When I retrieve my cart contents
    Then my cart should contain 1 item
    And the item quantity should be 2
    And the product ID in the cart should match the added product
    When I request recommendations based on my cart
    Then I should receive product recommendations
