const axios = require('axios');
const CircuitBreaker = require('opossum');

// Cache de instancias del Circuit Breaker
const circuitBreakers = {};

// Configuración del Circuit Breaker desde las variables de entorno
const THRESHOLD = parseInt(process.env.CIRCUIT_BREAKER_THRESHOLD) || 3;
const TIMEOUT = parseInt(process.env.CIRCUIT_BREAKER_TIMEOUT_MS) || 10000;
const VM_IP = process.env.MICROSERVICES_VM_IP;

// Mapeo de servicios a puertos
const SERVICE_PORTS = {
  'auth': process.env.AUTH_API_PORT || '8000',
  'todos': process.env.TODOS_API_PORT || '8082',
  'users': process.env.USERS_API_PORT || '8083',
  'frontend': process.env.FRONTEND_PORT || '8080'
};

// Función para obtener el circuit breaker de un servicio o crearlo si no existe
function getCircuitBreaker(service, method) {
  const key = `${service}_${method}`;
  
  if (!circuitBreakers[key]) {
    const breaker = new CircuitBreaker(makeRequest, {
      timeout: TIMEOUT,
      errorThresholdPercentage: 50,
      resetTimeout: 10000,
      failureThreshold: THRESHOLD
    });
    
    // Eventos del Circuit Breaker para logging
    breaker.on('open', () => {
      console.log(`Circuit Breaker for ${service} (${method}) is now OPEN`);
    });
    
    breaker.on('close', () => {
      console.log(`Circuit Breaker for ${service} (${method}) is now CLOSED`);
    });
    
    breaker.on('halfOpen', () => {
      console.log(`Circuit Breaker for ${service} (${method}) is now HALF-OPEN`);
    });
    
    breaker.on('fallback', () => {
      console.log(`Fallback executed for ${service} (${method})`);
    });
    
    circuitBreakers[key] = breaker;
  }
  
  return circuitBreakers[key];
}

// Función para realizar la petición al microservicio
async function makeRequest(options) {
  return await axios(options);
}

// Función para generar una respuesta fallback cuando el circuit breaker está abierto
function generateFallbackResponse(service) {
  switch(service) {
    case 'auth':
      return {
        status: 503,
        body: { 
          error: "Auth service is temporarily unavailable",
          circuitBreaker: "open"
        }
      };
    case 'todos':
      return {
        status: 503,
        body: { 
          error: "Todos service is temporarily unavailable",
          circuitBreaker: "open",
          data: []
        }
      };
    case 'users':
      return {
        status: 503,
        body: { 
          error: "Users service is temporarily unavailable",
          circuitBreaker: "open",
          data: []
        }
      };
    default:
      return {
        status: 503,
        body: { 
          error: "Service is temporarily unavailable",
          circuitBreaker: "open"
        }
      };
    case 'frontend':
      return {
        status: 503,
        body: { 
          error: "Frontend service is temporarily unavailable",
          circuitBreaker: "open"
        }
      };
  }
}

module.exports = async function (context, req) {
  try {
    const service = context.bindingData.service;
    const path = context.bindingData.path || '';
    const method = req.method.toLowerCase();
    
    // Validar si el servicio está soportado
    if (!SERVICE_PORTS[service]) {
      context.res = {
        status: 400,
        body: { error: `Service '${service}' not supported. Available services: ${Object.keys(SERVICE_PORTS).join(', ')}` }
      };
      return;
    }
    
    // Log para debugging
    context.log(`Requested service: ${service}, path: ${path}, method: ${method}`);
    context.log(`Available services: ${JSON.stringify(SERVICE_PORTS)}`);
    context.log(`Microservices VM IP: ${VM_IP}`);
    context.log(`Environment variables: MICROSERVICES_VM_IP=${process.env.MICROSERVICES_VM_IP}`);
    
    // Construir la URL del servicio
    const servicePort = SERVICE_PORTS[service];
    const serviceUrl = path ? `http://${VM_IP}:${servicePort}/${path}` : `http://${VM_IP}:${servicePort}`;
    
    // Construir opciones para la petición
    const requestOptions = {
      method: method,
      url: serviceUrl,
      headers: {
        ...req.headers,
        host: `${VM_IP}:${servicePort}`,
        'x-forwarded-for': req.headers['x-forwarded-for'] || req.ip
      }
    };
    
    // Añadir cuerpo a la petición si existe
    if (req.body && (method === 'post' || method === 'put')) {
      requestOptions.data = req.body;
    }
    
    // Obtener el Circuit Breaker para este servicio y método
    const breaker = getCircuitBreaker(service, method);
    
    // Verificar el estado actual del Circuit Breaker
    context.log(`Circuit Breaker state for ${service} (${method}): ${breaker.status.state}`);
    
    // Ejecutar la petición a través del Circuit Breaker
    const result = await breaker.fire(requestOptions)
      .catch(error => {
        // Si el Circuit Breaker está abierto o hay un error, devolver respuesta fallback
        context.log.error(`Error calling ${service} (${method}): ${error.message}`);
        return generateFallbackResponse(service);
      });
    
    // Si ya tenemos una respuesta formateada del fallback
    if (result.status && result.body) {
      context.res = result;
      return;
    }
    
    // Formatear la respuesta para el cliente
    context.res = {
      status: result.status,
      body: result.data,
      headers: {
        'Content-Type': result.headers?.['content-type'] || 'application/json',
        'x-circuit-breaker-status': breaker.status.state
      }
    };
    
  } catch (error) {
    context.log.error(`Unhandled error: ${error.message}`);
    context.res = {
      status: 500,
      body: { 
        error: "Internal server error in Circuit Breaker function",
        message: error.message
      }
    };
  }
};