from django.urls import path
from . import views

urlpatterns = [
    path('predict/', views.predict_variety, name='predict_variety'),
    path('predict-sugar-production/', views.predict_sugar_production, name='predict_sugar_production'),
]