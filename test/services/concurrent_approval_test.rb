require "test_helper"
require "timeout"

class ConcurrentApprovalTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup { setup_boq }

  teardown do
    # This class commits setup so separate database connections see the records.
    # Delete only the records created by this test, in foreign-key order.
    if @master
      item_ids = @master.boq_items.pluck(:id)
      draw_ids = LaborDrawItem.where(boq_item_id: item_ids).pluck(:labor_draw_request_id)
      LaborDrawItem.where(labor_draw_request_id: draw_ids).delete_all
      LaborDrawRequest.where(id: draw_ids).delete_all
      BoqItem.where(id: item_ids).delete_all
      BoqCategory.where(master_boq_id: @master.id).delete_all
      MasterBoq.where(id: @master.id).delete_all
    end
    User.where(id: [ @admin&.id, @engineer&.id ].compact).delete_all
  end

  test "simultaneous retries deduct a document once" do
    draw = build_draw(amount: 700)
    draw.save!
    results = approve_concurrently([ draw, draw ])
    assert results.all? { |result| result == :approved }, results.inspect
    assert_equal 700, @item.reload.labor_paid_amount
  end

  test "competing requests cannot both consume the same remaining budget" do
    first = build_draw(amount: 700)
    second = build_draw(amount: 700)
    first.save!
    second.save!
    results = approve_concurrently([ first, second ])
    assert_equal 1, results.count(:approved), results.inspect
    assert_equal 1, results.count(:budget_exceeded), results.inspect
    assert_equal 700, @item.reload.labor_paid_amount
    assert_equal 1, LaborDrawRequest.where(id: [ first.id, second.id ], status: :pending).count
  end

  test "simultaneous immediate submissions with one form key create and deduct once" do
    key = SecureRandom.uuid
    draws = 2.times.map { build_draw(amount: 700).tap { |draw| draw.user = @admin; draw.submission_key = key } }
    results = approve_concurrently(draws, submit: true)
    assert results.all? { |result| result == :approved }, results.inspect
    assert_equal 1, LaborDrawRequest.where(submission_key: key).count
    assert_equal 700, @item.reload.labor_paid_amount
  end

  test "competing immediate draws roll back the losing document and do not overspend" do
    draws = 2.times.map { build_draw(amount: 700).tap { |draw| draw.user = @admin } }
    results = approve_concurrently(draws, submit: true)
    assert_equal 1, results.count(:approved), results.inspect
    assert_equal 1, results.count(:budget_exceeded), results.inspect
    assert_equal 1, LaborDrawRequest.where(user: @admin).count
    assert_equal 700, @item.reload.labor_paid_amount
  end

  private

  def approve_concurrently(documents, submit: false)
    ready = Queue.new
    start = Queue.new
    threads = documents.map do |document|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          service = submit ? SubmitLaborDrawService : ApproveLaborDrawService
          service.new(document, actor: @admin).call
          :approved
        rescue ApproveLaborDrawService::BudgetExceeded
          :budget_exceeded
        rescue StandardError => error
          error
        end
      end
    end
    Timeout.timeout(15) do
      documents.size.times { ready.pop }
      documents.size.times { start << true }
      threads.map(&:value)
    end
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
    threads&.each(&:join)
  end
end
