import http from 'k6/http';
import { check, sleep, fail } from 'k6';
import { Counter } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const PAGE_SIZE = 24;

const rateLimited = new Counter('rate_limited');

export const options = {
    scenarios: {
        browse: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '30s', target: 10 },
                { duration: '1m', target: 20 },
                { duration: '30s', target: 20 },
                { duration: '20s', target: 0 }
            ],
            gracefulRampDown: '10s'
        }
    },
    thresholds: {
        http_req_failed: ['rate<0.01'],
        checks: ['rate>0.99'],
        'http_req_duration{name:children}': ['p(95)<800'],
        'http_req_duration{name:by_month}': ['p(95)<800'],
        'http_req_duration{name:path}': ['p(95)<300'],
        'http_req_duration{name:observations}': ['p(95)<5000']
    }
};

export function setup() {
    const username = __ENV.K6_USERNAME || 'jay';
    const password = __ENV.K6_PASSWORD;
    if (password === undefined || password === '') {
        fail('K6_PASSWORD is not set, run this through tools\\run_load_test.ps1');
    }

    const response = http.post(
        `${BASE_URL}/api/auth/login`,
        JSON.stringify({ username: username, password: password }),
        { headers: { 'Content-Type': 'application/json' }, tags: { name: 'login' } }
    );

    if (response.status !== 200) {
        fail(`login failed with status ${response.status}`);
    }

    return { token: response.json('accessToken') };
}

function apiRequest(path, body, token, name) {
    return {
        method: 'POST',
        url: `${BASE_URL}${path}`,
        body: JSON.stringify(body),
        params: {
            headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
            tags: { name: name }
        }
    };
}

function checkAll(responses) {
    for (const response of responses) {
        if (response.status === 429) {
            rateLimited.add(1);
        }
        check(response, { 'status is 200': (r) => r.status === 200 });
    }
}

export default function (data) {
    let taxonId = null;
    let lastObservations = null;
    const depth = 1 + Math.floor(Math.random() * 4);

    for (let level = 0; level <= depth; level++) {
        // one click: the same calls the explorer makes when a taxon opens
        const requests = [
            apiRequest('/api/dashboard/taxon-children', { parentTaxonId: taxonId }, data.token, 'children'),
            apiRequest('/api/dashboard/observations-by-month', { taxonId: taxonId }, data.token, 'by_month')
        ];
        if (taxonId !== null) {
            requests.push(apiRequest('/api/taxonomy/path', { taxonId: taxonId }, data.token, 'path'));
            requests.push(apiRequest('/api/taxonomy/observations', { taxonId: taxonId, pageSize: PAGE_SIZE }, data.token, 'observations'));
        }

        const responses = http.batch(requests);
        checkAll(responses);

        if (taxonId !== null && responses[3].status === 200) {
            lastObservations = responses[3].json();
        }

        sleep(1 + Math.random() * 2);

        if (level === depth || responses[0].status !== 200) {
            break;
        }

        const candidates = responses[0].json().filter((child) => child.hasChildren === true && child.observationCount > 0);
        if (candidates.length === 0) {
            break;
        }
        taxonId = candidates[Math.floor(Math.random() * candidates.length)].id;
    }

    // half the users press "load more" once
    if (lastObservations !== null && lastObservations.nextCursor && Math.random() < 0.5) {
        const cursor = lastObservations.nextCursor;
        const responses = http.batch([
            apiRequest('/api/taxonomy/observations', {
                taxonId: taxonId,
                pageSize: PAGE_SIZE,
                afterObservedDate: cursor.afterObservedDate,
                afterObservationId: cursor.afterObservationId
            }, data.token, 'observations')
        ]);
        checkAll(responses);
        sleep(1);
    }
}