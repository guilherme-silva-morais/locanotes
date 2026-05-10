require "base64"

# Cursor-based pagination for ActiveRecord scopes ordered by
# (created_at DESC, id DESC). Uses Postgres tuple comparison so the query is
# index-friendly (matches the composite index on (user_id, created_at, id)).
#
# Why cursor and not offset:
#   - offset shifts under concurrent writes (skips/duplicates between pages)
#   - cursor is anchored to a real (created_at, id) pair, so insertions before
#     the anchor don't affect what comes after.
#
# Cursor format: urlsafe base64 of "<created_at_iso8601_us>:<id>".
class CursorPagination
  DEFAULT_LIMIT = 20
  MAX_LIMIT = 100

  InvalidCursor = Class.new(StandardError)

  Result = Struct.new(:records, :next_cursor, :has_more, keyword_init: true)

  def initialize(scope, cursor: nil, limit: nil)
    @scope = scope
    @cursor = cursor.presence
    @limit = normalize_limit(limit)
  end

  def call
    base = @cursor ? apply_cursor(@scope) : @scope
    # Fetch one extra row to detect whether there's a "next page".
    fetched = base.limit(@limit + 1).to_a
    has_more = fetched.size > @limit
    records = fetched.first(@limit)

    Result.new(
      records: records,
      next_cursor: has_more ? encode_cursor(records.last) : nil,
      has_more: has_more
    )
  end

  private
    def apply_cursor(scope)
      ts, id = decode_cursor(@cursor)
      scope.where("(notes.created_at, notes.id) < (?, ?)", ts, id)
    end

    def encode_cursor(record)
      payload = "#{record.created_at.utc.iso8601(6)}:#{record.id}"
      Base64.urlsafe_encode64(payload, padding: false)
    end

    def decode_cursor(cursor)
      raw = Base64.urlsafe_decode64(cursor)
      ts_str, sep, id_str = raw.rpartition(":")
      raise InvalidCursor, "missing separator" if sep.empty?

      [ Time.iso8601(ts_str), Integer(id_str) ]
    rescue ArgumentError, TypeError
      raise InvalidCursor, "malformed cursor"
    end

    def normalize_limit(value)
      n = value.to_i
      return DEFAULT_LIMIT if n <= 0

      [ n, MAX_LIMIT ].min
    end
end
