import http from 'k6/http';
import { check } from 'k6';
import { sleep } from 'k6';

export const options = {
  scenarios: {
    load_test: {
      executor: 'ramping-vus',
      startVUs: 2,
      stages: [
        { duration: '1m', target: 8 },      // 1 dakikada 8 kullanıcıya çık
        { duration: '1m', target: 8 },      // 1 dakika 8 kullanıcıda kal
        { duration: '1m', target: 15 },     // 2 dakika 8 kullanıcıya çık
        { duration: '1m', target: 100 },     // 1 dakikada 25 kullanıcıya çık
        { duration: '2m', target: 100 },     // 2 dakika 100 kullanıcıda kal
        { duration: '1m', target: 0 }       // 1 dakikada sıfıra in
      ],
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<5000'],
    http_req_failed: ['rate<0.15'],
  }
};

export default function () {
  const BASE_URL = 'http://nginx';  // Docker network içindeki nginx adresi
  const params = {
    headers: {
      'User-Agent': 'k6-load-test',
    },
    timeout: 10000,
  };

  // CPU yükü oluştur
  for(let i = 0; i < 8000; i++) {
    Math.sqrt(i * i);
  }

  // Issues sayfası istekleri (ana yük)
  for (let i = 0; i < 3; i++) {
    let page = Math.floor(Math.random() * 5) + 1;
    let r3 = http.get(`${BASE_URL}/issues?page=${page}&per_page=1000&sort=updated_on:desc`, params);
    check(r3, {
      'issues sayfası başarılı': (r) => r.status === 200,
    });
    sleep(0.5);
  }

  // Ana sayfa isteği
  let r1 = http.get(`${BASE_URL}/`, params);
  check(r1, {
    'ana sayfa başarılı': (r) => r.status === 200,
  });

  // Projects sayfası isteği
  let r2 = http.get(`${BASE_URL}/projects?per_page=1000`, params);
  check(r2, {
    'projects sayfası başarılı': (r) => r.status === 200,
  });

  sleep(1);
}