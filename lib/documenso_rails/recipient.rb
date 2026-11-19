module DocumensoRails
  class Recipient
    attr_reader :id, :email, :name, :role, :signing_url, :raw

    def initialize(id:, email: nil, name: nil, role: nil, signing_url: nil, raw: {})
      @id = id
      @email = email
      @name = name
      @role = role
      @signing_url = signing_url
      @raw = raw
    end

    def self.from_api(hash)
      data = hash.transform_keys(&:to_s)
      new(
        id: data["id"],
        email: data["email"],
        name: data["name"],
        role: data["role"],
        signing_url: data["signingUrl"] || data["signing_url"],
        raw: data
      )
    end
  end
end
