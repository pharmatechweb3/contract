import { createApiClient } from 'src/libraries/axios/create-axios-instance';
import { createAppApiClient } from 'src/services';

export const useApi = () => {
  const api = createApiClient({ baseURL: 'https://api.themoviedb.org' });
  return createAppApiClient(api);
};
