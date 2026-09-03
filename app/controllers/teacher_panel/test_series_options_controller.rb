class TeacherPanel::TestSeriesOptionsController < ApplicationController

  before_action :authenticate_user!
  before_action :require_teacher

  layout "teacher"

  before_action :set_test_series
  before_action :set_test
  before_action :set_question

  before_action :set_option,
                only: %i[edit update destroy]


  # =========================================================
  # NEW
  # =========================================================
  # No separate option page.
  # Redirect back to the question page where the option
  # creation form is displayed.

  def new
    redirect_to teacher_panel_test_series_test_test_series_question_path(
      @test_series,
      @test,
      @question
    )
  end


  # =========================================================
  # CREATE
  # =========================================================

  def create

    @option = @question.test_series_options.new(option_params)

    # Automatically assign position if teacher didn't provide it
    if @option.position.blank?
      @option.position =
        (@question.test_series_options.maximum(:position) || 0) + 1
    end

    TestSeriesOption.transaction do

      @option.save!

      # Only one correct option per question
      if @option.is_correct?

        @question
          .test_series_options
          .where.not(id: @option.id)
          .update_all(is_correct: false)

      end

    end

    redirect_to teacher_panel_test_series_test_test_series_question_path(
      @test_series,
      @test,
      @question
    ),
    notice: "Option added successfully."

  rescue ActiveRecord::RecordInvalid

    # Rebuild options for the question page
    @options = @question.test_series_options.order(position: :asc)

    render "teacher_panel/test_series_questions/show",
           status: :unprocessable_entity

  end


  # =========================================================
  # EDIT
  # =========================================================

  def edit
  end


  # =========================================================
  # UPDATE
  # =========================================================

  def update

    TestSeriesOption.transaction do

      if option_params[:is_correct].to_s == "true"

        @question
          .test_series_options
          .where.not(id: @option.id)
          .update_all(is_correct: false)

      end

      @option.update!(option_params)

    end

    redirect_to teacher_panel_test_series_test_test_series_question_path(
      @test_series,
      @test,
      @question
    ),
    notice: "Option updated successfully."

  rescue ActiveRecord::RecordInvalid

    redirect_to teacher_panel_test_series_test_test_series_question_path(
      @test_series,
      @test,
      @question
    ),
    alert: @option.errors.full_messages.to_sentence

  end


  # =========================================================
  # DELETE
  # =========================================================

  def destroy

    @option.destroy

    redirect_to teacher_panel_test_series_test_test_series_question_path(
      @test_series,
      @test,
      @question
    ),
    notice: "Option deleted successfully."

  end


  private


  # =========================================================
  # TEST SERIES
  # =========================================================

  def set_test_series

    @test_series =
      TestSeries.find(params[:test_series_id])

  end


  # =========================================================
  # TEST
  # =========================================================

  def set_test

    @test =
      @test_series
        .test_series_tests
        .find(params[:test_series_test_id])

  end


  # =========================================================
  # QUESTION
  # =========================================================

  def set_question

    @question =
      @test
        .test_series_questions
        .find(params[:test_series_question_id])

  end


  # =========================================================
  # OPTION
  # =========================================================

  def set_option

    @option =
      @question
        .test_series_options
        .find(params[:id])

  end


  # =========================================================
  # STRONG PARAMETERS
  # =========================================================

  def option_params

    params.require(:test_series_option).permit(
      :option_text,
      :is_correct,
      :position
    )

  end


  # =========================================================
  # TEACHER ACCESS
  # =========================================================

  def require_teacher

    unless current_user.teacher.present?

      redirect_to root_path,
                  alert: "Teacher access required."

    end

  end

end