module Cmdk
  # The part of an item whose matched characters the runtime highlights while
  # searching (opt-in; an extension over the React API). Put the item's text
  # in it; the runtime wraps each matched run in `<mark cmdk-match>` and
  # restores the plain text when the search clears:
  #
  #   Cmdk::Item(value: 'posts', href: '/posts') do
  #     icon
  #     Cmdk::ItemLabel() { 'Posts' }
  #   end
  #
  # Matches are computed against the label's own text with the default
  # command-score algorithm. Keep the label to plain text: its children are
  # replaced by text nodes and marks while highlighted. Style matches with
  # `[cmdk-item-label] mark[cmdk-match]`.
  class ItemLabel < Base
    def initialize(**attributes)
      @attributes = attributes
    end

    def view_template(&block)
      span(**merged({ 'cmdk-item-label' => '' }, @attributes), &block)
    end
  end
end
