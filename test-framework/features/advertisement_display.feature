Feature: Advertisement Display
  As a system
  I want to display contextual advertisements
  So that users see relevant ads based on their browsing context

  Background:
    Given the microservices are healthy and running

  Scenario: Get ads with single context keyword
    When I request ads with context keywords "clothing"
    Then I should receive advertisements
    And the ads should be relevant to the context

  Scenario: Get ads with multiple context keywords
    When I request ads with context keywords "clothing,accessories,fashion"
    Then I should receive advertisements
    And the ads should be relevant to the context

  Scenario: Get ads with technology context
    When I request ads with context keywords "technology,gadgets"
    Then I should receive advertisements
    And the ads should be relevant to the context

  Scenario: Get ads with home goods context
    When I request ads with context keywords "home,kitchen,decor"
    Then I should receive advertisements
    And the ads should be relevant to the context

  Scenario: Get ads with empty context
    When I request ads with context keywords ""
    Then I should receive advertisements

  Scenario: Get ads multiple times for same context
    When I request ads with context keywords "clothing"
    And I request ads with context keywords "clothing"
    And I request ads with context keywords "clothing"
    Then I should receive advertisements
    And the ads should be relevant to the context

  Scenario: Get ads with different contexts sequentially
    When I request ads with context keywords "clothing"
    Then I should receive advertisements
    When I request ads with context keywords "technology"
    Then I should receive advertisements
    When I request ads with context keywords "home"
    Then I should receive advertisements
