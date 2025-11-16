Feature: Cross-Service Integration
  As a system
  I want services to work together seamlessly
  So that complex workflows function correctly

  Background:
    Given the microservices are healthy and running

  Scenario: End-to-end flow with all services
    Given I have a unique user ID
    # Product Catalog
    When I search for products with keyword "watch"
    Then I should receive search results
    # Cart
    When I add product "OLJCESPC7Z" to my cart with quantity 2
    And I retrieve my cart contents
    Then my cart should contain 1 items
    # Shipping
    When I request a shipping quote for the following address:
      | field          | value                    |
      | street_address | 1600 Amphitheatre Parkway|
      | city           | Mountain View            |
      | state          | CA                       |
      | country        | United States            |
      | zip_code       | 94043                    |
    Then I should receive a shipping quote
    # Currency
    When I convert 100 "USD" to "EUR"
    Then I should receive a valid conversion result
    # Payment
    When I charge 50.00 "USD" with valid credit card
    Then the payment should be successful
    # Ads
    When I request ads with context keywords "clothing"
    Then I should receive advertisements

  Scenario: Currency conversion affects order pricing
    Given I have a unique user ID
    When I add product "66VCHSJNUP" to my cart with quantity 1
    And I retrieve my cart contents
    Then my cart should contain 1 items
    # Get quote in USD
    When I request a shipping quote for the following address:
      | field          | value                    |
      | street_address | 1600 Amphitheatre Parkway|
      | city           | Mountain View            |
      | state          | CA                       |
      | country        | United States            |
      | zip_code       | 94043                    |
    Then I should receive a shipping quote
    # Convert currencies
    When I request the list of supported currencies
    Then the list should contain "EUR"
    When I convert 100 "USD" to "EUR"
    Then the converted amount should be in "EUR"

  Scenario: Product recommendations with ads and cart
    Given I have a unique user ID
    When I add product "OLJCESPC7Z" to my cart with quantity 1
    And I add product "66VCHSJNUP" to my cart with quantity 1
    And I get product recommendations
    Then I should receive product recommendations
    When I request ads with context keywords "fashion,clothing"
    Then I should receive advertisements

  Scenario: Complete purchase workflow
    Given I have a unique user ID
    # Browse and add to cart
    When I search for products with keyword "kitchen"
    And I add product "2ZYFJ3GM2N" to my cart with quantity 1
    And I retrieve my cart contents
    Then my cart should contain 1 items
    # Get shipping quote
    When I request a shipping quote for the following address:
      | field          | value           |
      | street_address | 123 Test Street |
      | city           | Toronto         |
      | state          | ON              |
      | country        | Canada          |
      | zip_code       | 12345           |
    Then I should receive a shipping quote
    # Process payment
    When I charge 200.00 "USD" with valid credit card
    Then the payment should be successful
    And I should receive a transaction ID
    # Ship the order
    When I ship an order to the following address:
      | field          | value           |
      | street_address | 123 Test Street |
      | city           | Toronto         |
      | state          | ON              |
      | country        | Canada          |
      | zip_code       | 12345           |
    Then the order should be shipped successfully
    And I should receive a tracking ID

  Scenario: Multi-currency shopping experience
    Given I have a unique user ID
    # Check supported currencies
    When I request the list of supported currencies
    Then I should receive a list of currency codes
    And the list should contain "USD"
    And the list should contain "EUR"
    # Convert various amounts
    When I convert 50 "USD" to "EUR"
    Then the converted amount should be in "EUR"
    When I convert 100 "EUR" to "JPY"
    Then the converted amount should be in "JPY"
    # Make payments in different currencies
    When I charge 100.00 "EUR" with valid credit card
    Then the payment should be successful
    When I charge 5000 "JPY" with valid credit card
    Then the payment should be successful

  Scenario: Shopping with recommendations and shipping
    Given I have a unique user ID
    # Add products and get recommendations
    When I add product "OLJCESPC7Z" to my cart with quantity 1
    And I get product recommendations
    Then I should receive product recommendations
    # Get ads based on cart contents
    When I request ads with context keywords "clothing,accessories"
    Then I should receive advertisements
    # Get shipping quote
    When I request a shipping quote for the following address:
      | field          | value                    |
      | street_address | 1600 Amphitheatre Parkway|
      | city           | Mountain View            |
      | state          | CA                       |
      | country        | United States            |
      | zip_code       | 94043                    |
    Then I should receive a shipping quote
    And the quote should have a valid cost
