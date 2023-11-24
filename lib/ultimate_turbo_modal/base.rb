# frozen_string_literal: true

class UltimateTurboModal::Base < Phlex::HTML
  prepend Phlex::DeferredRenderWithMainContent
  # @param padding [Boolean] Whether to add padding around the modal content
  # @param close_button [Boolean] Whether to show a close button
  # @param close_button_sr_label [String] Close button label for screen readers
  # @param close_button_data_action [String] `data-action` attribute for the close button
  # @param advance [Boolean] Whether to update the browser history when opening and closing the modal
  # @param header_divider [Boolean] Whether to show a divider between the header and the main content
  # @param footer_divider [Boolean] Whether to show a divider between the main content and the footer
  # @param title [String] The title of the modal
  # @param request [ActionDispatch::Request] The current Rails request object
  def initialize(
    padding: UltimateTurboModal.configuration.padding,
    close_button: UltimateTurboModal.configuration.close_button,
    close_button_sr_label: "Close modal",
    close_button_data_action: "modal#hideModal",
    advance: UltimateTurboModal.configuration.advance,
    header: UltimateTurboModal.configuration.header,
    header_divider: UltimateTurboModal.configuration.header_divider,
    footer_divider: UltimateTurboModal.configuration.footer_divider,
    title: nil, request: nil
  )
    @padding = padding
    @close_button = close_button
    @close_button_sr_label = close_button_sr_label
    @close_button_data_action = close_button_data_action
    @advance = !!advance
    @advance_url = advance if advance.present? && advance.is_a?(String)
    @title = title
    @header = header
    @header_divider = header_divider
    @footer_divider = footer_divider
    @request = request

    unless self.class.include?(Turbo::FramesHelper)
      self.class.include Turbo::FramesHelper
      self.class.include Turbo::StreamsHelper
      self.class.include Phlex::Rails::Helpers::ContentTag
      self.class.include Phlex::Rails::Helpers::Routes
      self.class.include Phlex::Rails::Helpers::Tag
    end
  end

  def template(&block)
    if turbo_frame?
      turbo_frame_tag("modal") do
        modal(&block)
      end
    elsif turbo_stream?
      Turbo::StreamsHelper.turbo_stream_action_tag("update", target: "modal") do
        modal(&block)
      end
    else
      render block
    end
  end

  def title(&block)
    @title_block = block
  end

  def footer(&block)
    @footer = block
  end

  private

  attr_accessor :request

  def padding? = !!@padding

  def close_button? = !!@close_button

  def title_block? = !!@title_block

  def title? = !!@title

  def header? = !!@header

  def footer? = @footer.present?

  def header_divider? = !!@header_divider && (@title_block || title?)

  def footer_divider? = !!@footer_divider && footer?

  def turbo_stream? = !!request&.format&.turbo_stream?

  def turbo_frame? = !!request&.headers&.key?("Turbo-Frame")

  def turbo? = turbo_stream? || turbo_frame?

  def advance? = !!@advance && !!@advance_url

  def advance_url
    return nil unless !!@advance
    @advance_url || request&.original_url
  end

  def respond_to_missing?(method, include_private = false)
    self.class.included_modules.any? { |mod| mod.instance_methods.include?(method) } || super
  end

  ## HTML components

  def modal(&)
    outer_divs do
      div_content do
        div_header
        div_main(&)
        div_footer if footer?
      end
    end
  end

  def outer_divs(&)
    div_dialog do
      div_overlay
      div_outer do
        div_inner(&)
      end
    end
  end

  def div_dialog(&)
    div(id: "modal-container",
      class: self.class::DIV_DIALOG_CLASSES,
      role: "dialog",
      aria: {
        labeled_by: "modal-title-h",
        modal: true
      },
      data: {
        controller: "modal",
        modal_target: "container",
        modal_advance_url_value: advance_url,
        action: "turbo:submit-end->modal#submitEnd keyup@window->modal#closeWithKeyboard click@window->modal#outsideModalClicked click->modal#outsideModalClicked",
        transition_enter: "ease-out duration-100",
        transition_enter_start: "opacity-0",
        transition_enter_end: "opacity-100",
        transition_leave: "ease-in duration-50",
        transition_leave_start: "opacity-100",
        transition_leave_end: "opacity-0",
        padding: padding?.to_s,
        title: title?.to_s,
        header: header?.to_s,
        close_button: close_button?.to_s,
        header_divider: header_divider?.to_s,
        footer_divider: footer_divider?.to_s
      }, &)
  end

  def div_overlay
    div(id: "modal-overlay", class: self.class::DIV_OVERLAY_CLASSES)
  end

  def div_outer(&)
    div(id: "modal-outer", class: self.class::DIV_OUTER_CLASSES, &)
  end

  def div_inner(&)
    div(id: "modal-inner", class: self.class::DIV_INNER_CLASSES, &)
  end

  def div_content(&)
    div(id: "modal-content", class: self.class::DIV_CONTENT_CLASSES, data: {modal_target: "content"}, &)
  end

  def div_main(&)
    div(id: "modal-main", class: self.class::DIV_MAIN_CLASSES, &)
  end

  def div_header(&)
    div(id: "modal-header", class: self.class::DIV_HEADER_CLASSES) do
      div_title
      button_close
    end
  end

  def div_title
    div(id: "modal-title", class: self.class::DIV_TITLE_CLASSES) do
      if @title_block.present?
        render @title_block
      else
        h3(id: "modal-title-h", class: self.class::DIV_TITLE_H_CLASSES) { @title }
      end
    end
  end

  def div_footer
    div(id: "modal-footer", class: self.class::DIV_FOOTER_CLASSES) do
      render @footer
    end
  end

  def button_close
    div(id: "modal-close", class: self.class::BUTTON_CLOSE_CLASSES) do
      close_button_tag do
        icon_close
        span(class: self.class::BUTTON_CLOSE_SR_ONLY_CLASSES) { @close_button_sr_label }
      end
    end
  end

  def close_button_tag(&)
    button(type: "button",
      aria: {label: "close"},
      class: self.class::CLOSE_BUTTON_TAG_CLASSES,
      data: {
        action: @close_button_data_action
      }, &)
  end

  def icon_close
    svg(class: self.class::ICON_CLOSE_CLASSES, fill: "currentColor", viewBox: "0 0 20 20") do |s|
      s.path(
        fill_rule: "evenodd",
        d: "M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z",
        clip_rule: "evenodd"
      )
    end
  end
end
