Feature: Shipping Quote Calculation
  As a customer
  I want to get shipping quotes
  So that I know the shipping cost for my order

  Scenario: Get shipping quote for domestic address
    Given I have items in my cart
    When I request a shipping quote for the following address:
      | field          | value                    |
      | street_address | 1600 Amphitheatre Parkway|
      | city           | Mountain View            |
      | state          | CA                       |
      | country        | United States            |
      | zip_code       | 94043                    |
    Then I should receive a shipping quote
    And the quote should have a valid cost
    And the quote should be in "USD" currency

  Scenario: Get shipping quote for international address
    Given I have items in my cart
    When I request a shipping quote for the following address:
      | field          | value           |
      | street_address | 123 Test Street |
      | city           | Toronto         |
      | state          | ON              |
      | country        | Canada          |
      | zip_code       | 12345           |
    Then I should receive a shipping quote
    And the quote should have a valid cost

  Scenario: Shipping quote is consistent for same address
    Given I have a unique user ID
    And I add product "OLJCESPC7Z" to my cart with quantity 1
    When I request a shipping quote for the following address:
      | field          | value                    |
      | street_address | 1600 Amphitheatre Parkway|
      | city           | Mountain View            |
      | state          | CA                       |
      | country        | United States            |
      | zip_code       | 94043                    |
    Then I should receive a shipping quote
    And I store the shipping cost as "first_quote"

    When I add product "66VCHSJNUP" to my cart with quantity 2
    And I request a shipping quote for the following address:
      | field          | value                    |
      | street_address | 1600 Amphitheatre Parkway|
      | city           | Mountain View            |
      | state          | CA                       |
      | country        | United States            |
      | zip_code       | 94043                    |
    Then I should receive a shipping quote
    And the quote should have a valid cost

  Scenario: Get shipping quote with empty cart
    Given I have a unique user ID
    And my cart is empty
    When I request a shipping quote for the following address:
      | field          | value                    |
      | street_address | 1600 Amphitheatre Parkway|
      | city           | Mountain View            |
      | state          | CA                       |
      | country        | United States            |
      | zip_code       | 94043                    |
    Then I should receive a shipping quote
    And the quote should have a valid cost

  Scenario: Verify shipping quote response structure
    Given I have items in my cart
    When I request a shipping quote for the following address:
      | field          | value                    |
      | street_address | 1600 Amphitheatre Parkway|
      | city           | Mountain View            |
      | state          | CA                       |
      | country        | United States            |
      | zip_code       | 94043                    |
    Then I should receive a shipping quote
    And the quote should have a currency code
    And the quote should have units
    And the quote should have nanos

  Scenario: Ship order to domestic address
    Given I have a unique user ID
    And I add product "OLJCESPC7Z" to my cart with quantity 1
    When I ship an order to the following address:
      | field          | value                    |
      | street_address | 1600 Amphitheatre Parkway|
      | city           | Mountain View            |
      | state          | CA                       |
      | country        | United States            |
      | zip_code       | 94043                    |
    Then the order should be shipped successfully
    And I should receive a tracking ID

  Scenario: Ship order to international address
    Given I have a unique user ID
    And I add product "66VCHSJNUP" to my cart with quantity 2
    When I ship an order to the following address:
      | field          | value           |
      | street_address | 123 Test Street |
      | city           | Toronto         |
      | state          | ON              |
      | country        | Canada          |
      | zip_code       | 12345           |
    Then the order should be shipped successfully
    And I should receive a tracking ID

  Scenario: Ship order with multiple items
    Given I have a unique user ID
    And I add product "OLJCESPC7Z" to my cart with quantity 1
    And I add product "66VCHSJNUP" to my cart with quantity 2
    And I add product "9SIQT8TOJO" to my cart with quantity 1
    When I ship an order to the following address:
      | field          | value                    |
      | street_address | 1600 Amphitheatre Parkway|
      | city           | Mountain View            |
      | state          | CA                       |
      | country        | United States            |
      | zip_code       | 94043                    |
    Then the order should be shipped successfully
    And I should receive a tracking ID

  Scenario: Ship order with empty cart
    Given I have a unique user ID
    And my cart is empty
    When I ship an order to the following address:
      | field          | value                    |
      | street_address | 1600 Amphitheatre Parkway|
      | city           | Mountain View            |
      | state          | CA                       |
      | country        | United States            |
      | zip_code       | 94043                    |
    Then the order should be shipped successfully
    And I should receive a tracking ID
