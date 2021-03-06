shared_examples 'custom attributes endpoints' do |attributable_name|
  let!(:custom_attribute1) { attributable.custom_attributes.create key: 'foo', value: 'foo' }
  let!(:custom_attribute2) { attributable.custom_attributes.create key: 'bar', value: 'bar' }

  describe "GET /#{attributable_name} with custom attributes filter" do
    let!(:other_attributable) { create attributable.class.name.underscore }

    context 'with an unauthorized user' do
      it 'does not filter by custom attributes' do
        get api("/#{attributable_name}", user), custom_attributes: { foo: 'foo', bar: 'bar' }

        expect(response).to have_gitlab_http_status(200)
        expect(json_response.size).to be 2
      end
    end

    it 'filters by custom attributes' do
      get api("/#{attributable_name}", admin), custom_attributes: { foo: 'foo', bar: 'bar' }

      expect(response).to have_gitlab_http_status(200)
      expect(json_response.size).to be 1
      expect(json_response.first['id']).to eq attributable.id
    end
  end

  describe "GET /#{attributable_name}/:id/custom_attributes" do
    context 'with an unauthorized user' do
      subject { get api("/#{attributable_name}/#{attributable.id}/custom_attributes", user) }

      it_behaves_like 'an unauthorized API user'
    end

    it 'returns all custom attributes' do
      get api("/#{attributable_name}/#{attributable.id}/custom_attributes", admin)

      expect(response).to have_gitlab_http_status(200)
      expect(json_response).to contain_exactly(
        { 'key' => 'foo', 'value' => 'foo' },
        { 'key' => 'bar', 'value' => 'bar' }
      )
    end
  end

  describe "GET /#{attributable_name}/:id/custom_attributes/:key" do
    context 'with an unauthorized user' do
      subject { get api("/#{attributable_name}/#{attributable.id}/custom_attributes/foo", user) }

      it_behaves_like 'an unauthorized API user'
    end

    it 'returns a single custom attribute' do
      get api("/#{attributable_name}/#{attributable.id}/custom_attributes/foo", admin)

      expect(response).to have_gitlab_http_status(200)
      expect(json_response).to eq({ 'key' => 'foo', 'value' => 'foo' })
    end
  end

  describe "PUT /#{attributable_name}/:id/custom_attributes/:key" do
    context 'with an unauthorized user' do
      subject { put api("/#{attributable_name}/#{attributable.id}/custom_attributes/foo", user), value: 'new' }

      it_behaves_like 'an unauthorized API user'
    end

    it 'creates a new custom attribute' do
      expect do
        put api("/#{attributable_name}/#{attributable.id}/custom_attributes/new", admin), value: 'new'
      end.to change { attributable.custom_attributes.count }.by(1)

      expect(response).to have_gitlab_http_status(200)
      expect(json_response).to eq({ 'key' => 'new', 'value' => 'new' })
      expect(attributable.custom_attributes.find_by(key: 'new').value).to eq 'new'
    end

    it 'updates an existing custom attribute' do
      expect do
        put api("/#{attributable_name}/#{attributable.id}/custom_attributes/foo", admin), value: 'new'
      end.not_to change { attributable.custom_attributes.count }

      expect(response).to have_gitlab_http_status(200)
      expect(json_response).to eq({ 'key' => 'foo', 'value' => 'new' })
      expect(custom_attribute1.reload.value).to eq 'new'
    end
  end

  describe "DELETE /#{attributable_name}/:id/custom_attributes/:key" do
    context 'with an unauthorized user' do
      subject { delete api("/#{attributable_name}/#{attributable.id}/custom_attributes/foo", user) }

      it_behaves_like 'an unauthorized API user'
    end

    it 'deletes an existing custom attribute' do
      expect do
        delete api("/#{attributable_name}/#{attributable.id}/custom_attributes/foo", admin)
      end.to change { attributable.custom_attributes.count }.by(-1)

      expect(response).to have_gitlab_http_status(204)
      expect(attributable.custom_attributes.find_by(key: 'foo')).to be_nil
    end
  end
end
