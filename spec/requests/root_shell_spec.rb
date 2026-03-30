require 'rails_helper'

RSpec.describe 'Root shell', type: :request do
  it 'renders the internal application frame' do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('lending_rails')
    expect(response.body).to include('Lending operations workspace')
    expect(response.body).to include('Operator sign in')
  end
end
