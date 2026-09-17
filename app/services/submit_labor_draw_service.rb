class SubmitLaborDrawService
  def initialize(draw, actor:, override: false, override_reason: nil)
    @draw, @actor = draw, actor
    @override, @override_reason = override, override_reason
  end

  def call
    actor = User.find(@actor.id)
    Pundit.authorize(actor, @draw, :create?)
    @draw.submission_key ||= SecureRandom.uuid
    existing = LaborDrawRequest.find_by(submission_key: @draw.submission_key)
    return owned_submission(existing, actor) if existing

    instant = actor.admin? && SystemSetting.enabled?(:admin_instant_labor_approval)
    LaborDrawRequest.transaction(requires_new: true) do
      # Lock before inserting line foreign keys, avoiding competing lock upgrades
      # when two Admin submissions approve against the same BOQ rows.
      if instant
        BoqItem.where(id: @draw.labor_draw_items.map(&:boq_item_id)).order(:id).lock.load
      end
      @draw.save!
      if instant
        ApproveLaborDrawService.new(@draw, actor: actor, override: @override, override_reason: @override_reason).call
      else
        @draw
      end
    end
  rescue ActiveRecord::RecordNotUnique
    # Concurrent retries of the same form return its committed result.
    existing = LaborDrawRequest.find_by(submission_key: @draw.submission_key)
    raise unless existing
    owned_submission(existing, actor)
  end

  private

  def owned_submission(document, actor)
    raise Pundit::NotAuthorizedError unless document.user_id == actor.id
    document
  end
end
