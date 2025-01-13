import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    load_test: {
      executor: 'ramping-vus',
      startVUs: 2,
      stages: [
        { duration: '10m', target: 100 },
      ],
    },
  },
  thresholds: {
    // 95. yüzdelik gecikmenin 5000 ms'in altında kalması
    http_req_duration: ['p(95)<5000'],
    // İsteklerin başarısız olma oranı %15'ten az olmalı
    http_req_failed: ['rate<0.15'],
  },
};

// Buraya kendi Redmine API Key'inizi yazın.
const REDMINE_API_KEY = 'API KEY';

export default function () {
  // Docker compose network içindeki nginx servisine hitap ediyorsanız:
  const BASE_URL = 'http://nginx';

  // API isteklerinde kullanılacak ortak parametreler
  const params = {
    headers: {
      'User-Agent': 'k6-load-test',
      'X-Redmine-API-Key': REDMINE_API_KEY,  // Redmine API Key başlığı
    },
    timeout: 10000,
  };

  // CPU yükü oluşturmak için basit bir döngü
  for (let i = 0; i < 8000; i++) {
    Math.sqrt(i * i);
  }

  // Issues sayfası istekleri (ana yük)
  for (let i = 0; i < 3; i++) {
    let page = Math.floor(Math.random() * 5) + 1;
    let resIssues = http.get(`${BASE_URL}/issues?page=${page}&per_page=1000&sort=updated_on:desc`, params);
    check(resIssues, {
      'issues sayfası başarılı': (r) => r.status === 200,
    });
    sleep(0.5);
  }

  // Ana sayfa isteği
  let resHome = http.get(`${BASE_URL}/`, params);
  check(resHome, {
    'ana sayfa başarılı': (r) => r.status === 200,
  });

  // Projects sayfası isteği
  let resProjects = http.get(`${BASE_URL}/projects?per_page=1000`, params);
  check(resProjects, {
    'projects sayfası başarılı': (r) => r.status === 200,
  });

  // Döngü turu arasında kısa bekleme
  sleep(1);
}
